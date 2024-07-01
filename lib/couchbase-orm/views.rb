# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

require 'active_model'

module CouchbaseOrm
  module Views
    extend ActiveSupport::Concern

    module ClassMethods
      # Defines a Couchbase view with dynamic method creation.
      #
      # Couchbase views allow you to create custom queries on your data using map and reduce functions.
      # They are defined in design documents and can be queried to retrieve documents or aggregated data.
      # For more details, see the [Couchbase Views Basics](https://docs.couchbase.com/server/current/learn/views/views-basics.html).
      #
      # @param name [Symbol, String] The name of the view.
      # @param map [String, nil] The map function for the view (optional).
      # @param emit_key [Symbol, Array<Symbol>, nil] The key(s) to emit from the map function (optional).
      # @param reduce [String, nil] The reduce function for the view (optional).
      # @param options [Hash] Additional options for the view query.
      # @return [void]
      # @raise [ArgumentError] if the class already responds to the given name.
      #
      # @example Define a simple view to emit documents by `created_at`
      #   class MyModel
      #     include CouchbaseOrm::Model
      #     view :by_created_at, emit_key: :created_at
      #   end
      #
      #   # You can now use the dynamically defined method:
      #   results = MyModel.by_created_at
      #
      # @example Define a view with multiple emit keys
      #   class MyModel
      #     include CouchbaseOrm::Model
      #     view :by_user_and_date, emit_key: [:user_id, :created_at]
      #   end
      #
      #   # Use the defined view method
      #   results = MyModel.by_user_and_date
      #
      # @example Define a view with a custom map function
      #   class MyModel
      #     include CouchbaseOrm::Model
      #     view :by_custom_map, map: <<-MAP
      #       function (doc) {
      #         if (doc.type === "my_model") {
      #           emit(doc.custom_field, null);
      #         }
      #       }
      #     MAP
      #   end
      #
      #   # Use the defined view method
      #   results = MyModel.by_custom_map
      def view(name, map: nil, emit_key: nil, reduce: nil, **options)
        raise ArgumentError.new("#{self} already respond_to? #{name}") if self.respond_to?(name)

        if emit_key.is_a?(Array)
          emit_key.each do |key|
            raise "unknown emit_key attribute for view :#{name}, emit_key: :#{key}" if key && !attribute_names.include?(key.to_s)
          end
        elsif emit_key && !attribute_names.include?(emit_key.to_s)
          raise "unknown emit_key attribute for view :#{name}, emit_key: :#{emit_key}"
        end

        options = ViewDefaults.merge(options)

        method_opts = {}
        method_opts[:map]    = map    if map
        method_opts[:reduce] = reduce if reduce

        unless method_opts.key? :map
          if emit_key.instance_of?(Array)
            method_opts[:map] = <<~EMAP
              function(doc) {
                  if (doc.type === "{{design_document}}") {
                      emit([#{emit_key.map{ |key| 'doc.' + key.to_s }.join(',')}], null);
                  }
              }
            EMAP
          else
            emit_key ||= :created_at
            method_opts[:map] = <<~EMAP
              function(doc) {
                  if (doc.type === "{{design_document}}") {
                      emit(doc.#{emit_key}, null);
                  }
              }
            EMAP
          end
        end

        @views ||= {}

        name = name.to_sym
        @views[name] = method_opts

        singleton_class.__send__(:define_method, name) do |**opts, &result_modifier|
          opts = options.merge(opts).reverse_merge(scan_consistency: :request_plus)
          CouchbaseOrm.logger.debug("View [#{@design_document}, #{name.inspect}] options: #{opts.inspect}")
          if result_modifier
            include_docs(bucket.view_query(@design_document, name.to_s,
                                           Couchbase::Options::View.new(**opts.except(:include_docs)))).map(&result_modifier)
          elsif opts[:include_docs]
            include_docs(bucket.view_query(@design_document, name.to_s,
                                           Couchbase::Options::View.new(**opts.except(:include_docs))))
          else
            bucket.view_query(@design_document, name.to_s, Couchbase::Options::View.new(**opts.except(:include_docs)))
          end
        end
      end
      ViewDefaults = {include_docs: true}.freeze

      # Sets up a Couchbase view and a corresponding finder method for the given attribute.
      #
      # Couchbase views allow you to create custom queries on your data using map and reduce functions.
      # They are defined in design documents and can be queried to retrieve documents or aggregated data.
      # For more details, see the [Couchbase Views Basics](https://docs.couchbase.com/server/current/learn/views/views-basics.html).
      #
      # @param attr [Symbol] The attribute to create the view and finder method for.
      # @param validate [Boolean] Whether to validate the presence of the attribute (default: true).
      # @param find_method [Symbol, String, nil] The name of the finder method to be created (optional).
      # @param view_method [Symbol, String, nil] The name of the view method to be created (optional).
      # @return [void]
      #
      # @example Define an index view for the `email` attribute
      #   class User
      #     include CouchbaseOrm::Model
      #     index_view :email
      #   end
      #
      #   # This creates a view method `by_email` and a finder method `find_by_email`
      #   users_by_email = User.by_email(key: 'user@example.com')
      #   user = User.find_by_email('user@example.com')
      #
      # @example Define an index view for the `username` attribute with custom method names
      #   class User
      #     include CouchbaseOrm::Model
      #     index_view :username, find_method: :find_user_by_username, view_method: :by_username_view
      #   end
      #
      #   # This creates a view method `by_username_view` and a finder method `find_user_by_username`
      #   users_by_username = User.by_username_view(key: 'john_doe')
      #   user = User.find_user_by_username('john_doe')
      def index_view(attr, validate: true, find_method: nil, view_method: nil)
        view_method ||= "by_#{attr}"
        find_method ||= "find_#{view_method}"

        validates(attr, presence: true) if validate
        view view_method, emit_key: attr

        instance_eval "
                    def self.#{find_method}(#{attr})
                        #{view_method}(key: #{attr})
                    end
                ", __FILE__, __LINE__ - 4
      end

      def ensure_design_document!
        return false unless @views && !@views.empty?

        existing = {}
        update_required = false

          # Grab the existing view details
        begin
          ddoc = bucket.view_indexes.get_design_document(@design_document, :production)
        rescue Couchbase::Error::DesignDocumentNotFound
        end
        existing = ddoc.views if ddoc
        views_actual = {}
          # Fill in the design documents
        @views.each do |name, document|
          views_actual[name.to_s] = Couchbase::Management::View.new(
            document[:map]&.gsub('{{design_document}}', @design_document),
            document[:reduce]&.gsub('{{design_document}}', @design_document)
          )
        end

          # Check there are no changes we need to apply
        views_actual.each do |name, desired|
          check = existing[name]
          if check
            cmap = (check.map || '').gsub(/\s+/, '')
            creduce = (check.reduce || '').gsub(/\s+/, '')
            dmap = (desired.map || '').gsub(/\s+/, '')
            dreduce = (desired.reduce || '').gsub(/\s+/, '')

            unless cmap == dmap && creduce == dreduce
              update_required = true
              break
            end
          else
            update_required = true
            break
          end
        end

          # Updated the design document
        if update_required
          document = Couchbase::Management::DesignDocument.new
          document.views = views_actual
          document.name = @design_document
          bucket.view_indexes.upsert_design_document(document, :production)

          true
        else
          false
        end
      end

      private

      def include_docs(view_result)
        if view_result.rows.length > 1
          self.find(view_result.rows.map(&:id))
        elsif view_result.rows.length == 1
          [self.find(view_result.rows.first.id)]
        else
          []
        end
      end
    end
  end
end
