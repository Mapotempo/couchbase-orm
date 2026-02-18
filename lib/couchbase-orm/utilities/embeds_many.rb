# frozen_string_literal: true

module CouchbaseOrm
# rubocop:disable Metrics/ModuleLength
  module EmbedsMany
    def embeds_many(name, class_name: nil, store_as: nil, validate: true, polymorphic: false, default: nil)
      storage_key = (store_as || name).to_sym
      attribute storage_key, :array, type: :hash, default: []

      instance_var = "@__assoc_#{name}"
      klass_name = (class_name || name.to_s.singularize.camelize)

      # Handle polymorphic parameter: can be true, false, or array of allowed types
      is_polymorphic = polymorphic.is_a?(Array) || polymorphic == true
      allowed_types = polymorphic.is_a?(Array) ? polymorphic.map { |t| t.to_s.camelize } : nil

      set_embedded(name, {
        type: :many,
        class_name: klass_name,
        key: storage_key,
        name: name,
        instance_var: instance_var,
        polymorphic: is_polymorphic,
        allowed_types: allowed_types,
        default: default,
      })

      if validate
        validates_embedded(name)
        validates_with CouchbaseOrm::PolymorphicTypeValidator, attributes: [name], allowed_types: allowed_types if allowed_types.present?
      end

      if is_polymorphic
        define_polymorphic_embeds_many_reader(name, storage_key, instance_var, default)
        define_polymorphic_embeds_many_writer(name, storage_key, instance_var)
      else
        define_standard_embeds_many_reader(name, storage_key, instance_var, klass_name, default)
        define_standard_embeds_many_writer(name, storage_key, instance_var, klass_name)
      end

      define_method(:"#{name}_reset") do
        remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
      end
    end

    private

    # Returns a lambda that wraps objects in an array safely
    # Similar to ActiveSupport's Array.wrap, but duplicates arrays to prevent shared references
    def array_wrap_lambda
      lambda do |obj|
        if obj.nil?
          []
        elsif obj.is_a?(Array)
          obj.dup
        else
          [obj]
        end
      end
    end

    def define_polymorphic_embeds_many_reader(name, storage_key, instance_var, default_value)
      wrap_array = array_wrap_lambda

      define_method(name) do
        return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

        raw_array = read_attribute(storage_key)
        if raw_array.blank?
          if default_value
            default_obj = default_value.is_a?(Proc) ? instance_exec(&default_value) : default_value
            return self.send("#{name}=", wrap_array.call(default_obj))
          end
          return instance_variable_set(instance_var, [])
        end

        embedded_objects = raw_array.map do |raw|
          next unless raw.present?

          type = raw['type'] || raw[:type]
          next unless type.present?

          klass = type.constantize
          attrs = raw.dup
          attrs.delete('type')
          attrs.delete(:type)
          obj = klass.new(attrs)
          obj.embedded = true
          obj.polymorphic_embedded = true
          obj
        end.compact

        instance_variable_set(instance_var, embedded_objects)
      end
    end

    def define_polymorphic_embeds_many_writer(name, storage_key, instance_var)
      define_method("#{name}=") do |val|
        embedded_objects = []
        serialized = []

        Array(val).each do |v|
          next if v.nil?

          obj = if v.is_a?(Hash)
                  type_name = v[:type] || v['type']
                  raise ArgumentError.new("Cannot infer type from Hash for polymorphic embeds_many. Include 'type' key with class name.") unless type_name.present?

                  klass = type_name.to_s.camelize.constantize
                  attrs = v.dup
                  attrs.delete(:type)
                  attrs.delete('type')
                  klass.new(attrs)
                else
                  v
                end

          obj.embedded = true
          obj.polymorphic_embedded = true
          raw = obj.serializable_hash
          raw.delete('id') if raw['id'].blank?

          embedded_objects << obj
          serialized << raw
        end

        write_attribute(storage_key, serialized)
        instance_variable_set(instance_var, embedded_objects)
      end
    end

    def define_standard_embeds_many_reader(name, storage_key, instance_var, klass_name, default_value)
      wrap_array = array_wrap_lambda

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

        raw_array = read_attribute(storage_key)
        if raw_array.blank?
          if default_value
            default_obj = default_value.is_a?(Proc) ? instance_exec(&default_value) : default_value
            return self.send("#{name}=", wrap_array.call(default_obj))
          end
          return instance_variable_set(instance_var, [])
        end

        klass = send("_resolve_embedded_class_for_#{name}")
        embedded_objects = raw_array.map do |raw|
          obj = klass.new(raw)
          obj.embedded = true
          obj
        end

        instance_variable_set(instance_var, embedded_objects)
      end
    end

    def define_standard_embeds_many_writer(name, storage_key, instance_var, _klass_name)
      define_method("#{name}=") do |val|
        klass = send("_resolve_embedded_class_for_#{name}")

        embedded_objects = []
        serialized = []

        Array(val).each do |v|
          obj = v.is_a?(klass) ? v : klass.new(v)
          obj.embedded = true
          raw = obj.serializable_hash
          raw.delete('id') if raw['id'].blank?
          embedded_objects << obj
          serialized << raw
        end

        write_attribute(storage_key, serialized)
        instance_variable_set(instance_var, embedded_objects)
      end
    end
  end
# rubocop:enable Metrics/ModuleLength
end
