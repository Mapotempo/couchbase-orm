# frozen_string_literal: true

require 'active_model'
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/try'

module CouchbaseOrm
  module N1ql
    extend ActiveSupport::Concern
    NO_VALUE = :no_value_specified
      # sanitize for injection query
    def self.sanitize(value)
      if value.is_a?(String)
        value.gsub("'", "''").gsub('\\'){ '\\\\' }.gsub('"', '\"')
      elsif value.is_a?(Array)
        value.map{ |v| sanitize(v) }
      else
        value
      end
    end

    module ClassMethods
      # Defines a N1QL query method with dynamic method creation.
      #
      # N1QL (Non-first Normal Form Query Language) is a powerful query language for Couchbase
      # that allows you to perform complex queries on your data.
      # For more details, see the [Couchbase N1QL Documentation](https://docs.couchbase.com/server/current/n1ql/n1ql-intro/index.html).
      #
      # @param name [Symbol, String] The name of the N1QL query method.
      # @param query_fn [Proc, nil] An optional function to customize the query.
      # @param emit_key [Symbol, Array<Symbol>] The key(s) to emit from the query (optional, defaults to an empty array).
      # @param custom_order [String, nil] An optional parameter to define custom ordering for the query.
      # @param options [Hash] Additional options for the N1QL query.
      # @return [void]
      # @raise [ArgumentError] if the class already responds to the given name.
      #
      # @example Define a N1QL query to find documents by `email`
      #   class User
      #     include CouchbaseOrm::Model
      #     n1ql :find_by_email, emit_key: :email
      #   end
      #
      #   # This creates a query method `find_by_email`
      #   users = User.find_by_email(key: 'user@example.com')
      #
      # @example Define a N1QL query with custom ordering
      #   class User
      #     include CouchbaseOrm::Model
      #     n1ql :ordered_by_creation, emit_key: :created_at, custom_order: 'ORDER BY created_at DESC'
      #   end
      #
      #   # This creates a query method `ordered_by_creation`
      #   users = User.ordered_by_creation
      #
      # @example Define a N1QL query with a custom query function
      #   class User
      #     include CouchbaseOrm::Model
      #     n1ql :custom_query, query_fn: ->(keys) { "SELECT * FROM `bucket` WHERE #{keys.map { |k| "`#{k}` = ?" }.join(' AND ')}" }, emit_key: [:email, :username]
      #   end
      #
      #   # This creates a query method `custom_query`
      #   users = User.custom_query(key: { email: 'user@example.com', username: 'johndoe' })
      def n1ql(name, query_fn: nil, emit_key: [], custom_order: nil, **options)
        raise ArgumentError.new("#{self} already respond_to? #{name}") if self.respond_to?(name)

        emit_key = Array.wrap(emit_key)
        emit_key.each do |key|
          raise "unknown emit_key attribute for n1ql :#{name}, emit_key: :#{key}" if key && !attribute_names.include?(key.to_s)
        end
        options = N1QL_DEFAULTS.merge(options)
        method_opts = {}
        method_opts[:emit_key] = emit_key

        @indexes ||= {}
        @indexes[name] = method_opts

        singleton_class.__send__(:define_method, name) do |key: NO_VALUE, **opts, &result_modifier|
          opts = options.merge(opts).reverse_merge(scan_consistency: :request_plus)
          values = key == NO_VALUE ? NO_VALUE : convert_values(method_opts[:emit_key], key)
          current_query = run_query(method_opts[:emit_key], values, query_fn, custom_order: custom_order,
                                                                              **opts.except(:include_docs, :key))
          if result_modifier
            current_query.results(&result_modifier)
          elsif opts[:include_docs]
            results = current_query.results.to_a
            results = if results.empty?
                        results
                      else
                        find(results, **opts.slice(:quiet, :chunck))
                      end
            ResultsProxy.new(Array.wrap(results))
          else
            current_query.results
          end
        end
      end
      N1QL_DEFAULTS = { include_docs: true }.freeze

      # Sets up a Couchbase N1QL query and a corresponding finder method for the given attribute.
      #
      # N1QL (Non-first Normal Form Query Language) is a powerful query language for Couchbase
      # that allows you to perform complex queries on your data.
      # For more details, see the [Couchbase N1QL Documentation](https://docs.couchbase.com/server/current/n1ql/n1ql-intro/index.html).
      #
      # @param attr [Symbol] The attribute to create the N1QL query and finder method for.
      # @param validate [Boolean] Whether to validate the presence of the attribute (default: true).
      # @param find_method [Symbol, String, nil] The name of the finder method to be created (optional).
      # @param n1ql_method [Symbol, String, nil] The name of the N1QL query method to be created (optional).
      # @return [void]
      # @raise [ArgumentError] if the class already responds to the given name.
      #
      # @example Define an index N1QL query for the `email` attribute
      #   class User
      #     include CouchbaseOrm::Model
      #     index_n1ql :email
      #   end
      #
      #   # This creates a N1QL query method `by_email` and a finder method `find_by_email`
      #   users = User.by_email(key: ['user@example.com'])
      #   user = User.find_by_email('user@example.com')
      #
      # @example Define an index N1QL query for the `username` attribute with custom method names
      #   class User
      #     include CouchbaseOrm::Model
      #     index_n1ql :username, find_method: :find_user_by_username, n1ql_method: :by_username_n1ql
      #   end
      #
      #   # This creates a N1QL query method `by_username_n1ql` and a finder method `find_user_by_username`
      #   users = User.by_username_n1ql(key: ['john_doe'])
      #   user = User.find_user_by_username('john_doe')
      def index_n1ql(attr, validate: true, find_method: nil, n1ql_method: nil)
        n1ql_method ||= "by_#{attr}"
        find_method ||= "find_#{n1ql_method}"

        validates(attr, presence: true) if validate
        n1ql n1ql_method, emit_key: attr

        define_singleton_method find_method do |value|
          send n1ql_method, key: [value]
        end
      end

      private

      def convert_values(keys, values)
        return values if keys.empty? && Array.wrap(values).any?

        keys.zip(Array.wrap(values)).map do |key, value_before_type_cast|
          serialize_value(key, value_before_type_cast)
        end
      end

      def build_where(keys, values)
        where = values == NO_VALUE ? '' : keys.zip(Array.wrap(values))
                                              .reject { |key, value| key.nil? && value.nil? }
                                              .map { |key, value| build_match(key, value) }
                                              .join(' AND ')
        "type=\"#{design_document}\" #{'AND ' + where unless where.blank?}"
      end

        # order-by-clause ::= ORDER BY ordering-term [ ',' ordering-term ]*
        # ordering-term ::= expr [ ASC | DESC ] [ NULLS ( FIRST | LAST ) ]
        # see https://docs.couchbase.com/server/5.0/n1ql/n1ql-language-reference/orderby.html
      def build_order(keys, descending)
        keys.dup.push('meta().id').map { |k| "#{k} #{descending ? 'desc' : 'asc'}" }.join(',').to_s
      end

      def build_limit(limit)
        limit ? "limit #{limit}" : ''
      end

      def run_query(keys, values, query_fn, custom_order: nil, descending: false, limit: nil, **options)
        if query_fn
          N1qlProxy.new(query_fn.call(bucket, values, Couchbase::Options::Query.new(**options)))
        else
          bucket_name = bucket.name
          where = build_where(keys, values)
          order = custom_order || build_order(keys, descending)
          limit = build_limit(limit)
          n1ql_query = "select raw meta().id from `#{bucket_name}` where #{where} order by #{order} #{limit}"
          result = cluster.query(n1ql_query, Couchbase::Options::Query.new(**options))
          CouchbaseOrm.logger.debug { "N1QL query: #{n1ql_query} return #{result.rows.to_a.length} rows" }
          N1qlProxy.new(result)
        end
      end
    end
  end
end
