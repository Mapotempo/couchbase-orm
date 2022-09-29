# frozen_string_literal: true

module CouchbaseOrm
  module HasMany
    # :foreign_key, :class_name, :through
    def has_many(model, class_name: nil, foreign_key: nil, through: nil, through_class: nil, through_key: nil, type: :view, **options)
      class_name = (class_name || model.to_s.singularize.camelcase).to_s
      foreign_key = (foreign_key || ActiveSupport::Inflector.foreign_key(name)).to_sym
      if through || through_class
        remote_class = class_name
        class_name = (through_class || through.to_s.camelcase).to_s
        through_key = (through_key || "#{remote_class.underscore}_id").to_sym
        remote_method = :"by_#{foreign_key}_with_#{through_key}"
      else
        remote_method = :"find_by_#{foreign_key}"
      end

      instance_var = "@__assoc_#{model}"

      klass = begin
        class_name.constantize
      rescue NameError
        warn "WARNING: #{class_name} referenced in #{name} before it was aded"

        # Open the class early - load order will have to be changed to prevent this.
        # Warning notice required as a misspelling will not raise an error
        Object.class_eval <<-EKLASS, __FILE__, __LINE__ + 1
                            class #{class_name} < CouchbaseOrm::Base # class Books < CouchbaseOrm::Base
                                attribute :#{foreign_key}            #   attribute :author_id
                            end                                      # end
        EKLASS
        class_name.constantize
      end

      build_index(type, klass, remote_class, remote_method, through_key, foreign_key)

      if remote_class
        define_method(model) do
          return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

          remote_klass = remote_class.constantize
          raise ArgumentError, "Can't find #{remote_method} without an id" unless id.present?

          enum = klass.__send__(remote_method, key: id) do |row|
            case type
            when :n1ql
              remote_klass.find(row)
            when :view
              remote_klass.find(row[through_key])
            else
              raise 'type is unknown'
            end
          end

          instance_variable_set(instance_var, enum)
        end
      else
        define_method(model) do
          return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

          instance_variable_set(instance_var, id ? klass.__send__(remote_method, id) : [])
        end
      end

      @associations ||= []
      @associations << [model, options[:dependent]]
    end

    def build_index(type, klass, remote_class, remote_method, through_key, foreign_key)
      case type
      when :n1ql
        build_index_n1ql(klass, remote_class, remote_method, through_key, foreign_key)
      when :view
        build_index_view(klass, remote_class, remote_method, through_key, foreign_key)
      else
        raise 'type is unknown'
      end
    end

    def build_index_view(klass, remote_class, remote_method, through_key, foreign_key)
      if remote_class
        klass.class_eval do
          view remote_method, map: <<-EMAP
                        function(doc) {
                            if (doc.type === "{{design_document}}" && doc.#{through_key}) {
                                emit(doc.#{foreign_key}, null);
                            }
                        }
          EMAP
        end
      else
        klass.class_eval do
          index_view foreign_key, validate: false
        end
      end
    end

    def build_index_n1ql(klass, remote_class, remote_method, through_key, foreign_key)
      if remote_class
        klass.class_eval do
          n1ql remote_method, emit_key: 'id', query_fn: proc { |bucket, values, options|
            raise ArgumentError, 'values[0] must not be blank' if values[0].blank?

            cluster.query(<<~QUERY, options)
              SELECT raw #{through_key} FROM `#{bucket.name}`#{' '}
              WHERE type = \"#{design_document}\" AND #{foreign_key} = #{quote(values[0])}
            QUERY
          }
        end
      else
        klass.class_eval do
          index_n1ql foreign_key, validate: false
        end
      end
    end
  end
end
