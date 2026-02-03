# frozen_string_literal: true

module CouchbaseOrm
  module EmbedsMany
    def embeds_many(name, class_name: nil, store_as: nil, validate: true, polymorphic: false)
      storage_key = (store_as || name).to_sym
      attribute storage_key, :array, type: :hash, default: []

      instance_var = "@__assoc_#{name}"
      klass_name = (class_name || name.to_s.singularize.camelize)

      set_embedded(name, {
        type: :many,
        class_name: klass_name, # store as string, resolve later
        key: storage_key,
        name: name,
        instance_var: instance_var,
        polymorphic: polymorphic,
      })

      validates_embedded(name) if validate

      if polymorphic
        # Add types attribute for polymorphic associations
        types_key = :"#{name}_types"
        attribute types_key, :array, type: :string, default: []

        # Polymorphic reader
        define_method(name) do
          return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

          raw_array = read_attribute(storage_key)
          types_array = read_attribute(types_key)

          embedded_objects = []
          raw_array.each_with_index do |raw, index|
            type = types_array[index]
            next unless raw.present? && type.present?

            klass = type.constantize
            obj = klass.new(raw)
            obj.embedded = true
            embedded_objects << obj
          end

          instance_variable_set(instance_var, embedded_objects)
        end

        # Polymorphic writer
        define_method("#{name}=") do |val|
          embedded_objects = []
          serialized = []
          types = []

          Array(val).each do |v|
            if v.nil?
              next
            elsif v.is_a?(Hash)
              # Extract type from hash
              type_name = v[:type] || v['type']
              raise ArgumentError, "Cannot infer type from Hash for polymorphic embeds_many. Include 'type' key with class name." unless type_name.present?
              
              klass = type_name.to_s.camelize.constantize
              # Remove type from attributes before creating object
              attrs = v.dup
              attrs.delete(:type)
              attrs.delete('type')
              obj = klass.new(attrs)
            else
              obj = v
            end
            
            obj.embedded = true

            raw = obj.serialized_attributes
            raw.delete('id') if raw['id'].blank?

            embedded_objects << obj
            serialized << raw
            types << obj.class.name
          end

          write_attribute(storage_key, serialized)
          write_attribute(types_key, types)
          instance_variable_set(instance_var, embedded_objects)
        end
      else
        # Lazy class resolution method
        define_method("_resolve_embedded_class_for_#{name}") do
          @__resolved_classes ||= {}
          @__resolved_classes[name] ||= begin
            klass_name.constantize
          rescue NameError => e
            warn "WARNING: #{klass_name} could not be resolved in #{self.class.name}: #{e.message}"
            raise
          end
        end

        define_method(name) do
          return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

          klass = send("_resolve_embedded_class_for_#{name}")
          embedded_objects = read_attribute(storage_key).map do |raw|
            obj = klass.new(raw)
            obj.embedded = true
            obj
          end

          instance_variable_set(instance_var, embedded_objects)
        end

        define_method("#{name}=") do |val|
          klass = send("_resolve_embedded_class_for_#{name}")

          embedded_objects = []
          serialized = []

          Array(val).each do |v|
            obj = v.is_a?(klass) ? v : klass.new(v)
            obj.embedded = true
            raw = obj.serialized_attributes
            raw.delete('id') if raw['id'].blank?
            embedded_objects << obj
            serialized << raw
          end

          write_attribute(storage_key, serialized)
          instance_variable_set(instance_var, embedded_objects)
        end
      end

      define_method(:"#{name}_reset") do
        remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
      end
    end
  end
end
