# frozen_string_literal: true

module CouchbaseOrm
  module EmbedsMany
    def embeds_many(name, class_name: nil, store_as: nil, validate: true, polymorphic: false)
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
      })

      validates_embedded(name) if validate

      if is_polymorphic
        define_polymorphic_embeds_many_reader(name, storage_key, instance_var)
        define_polymorphic_embeds_many_writer(name, storage_key, instance_var, allowed_types)
      else
        define_standard_embeds_many_reader(name, storage_key, instance_var, klass_name)
        define_standard_embeds_many_writer(name, storage_key, instance_var, klass_name)
      end

      define_method(:"#{name}_reset") do
        remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
      end
    end

    private

    def define_polymorphic_embeds_many_reader(name, storage_key, instance_var)
      define_method(name) do
        return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

        raw_array = read_attribute(storage_key)
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
          obj
        end.compact

        instance_variable_set(instance_var, embedded_objects)
      end
    end

    def define_polymorphic_embeds_many_writer(name, storage_key, instance_var, allowed_types)
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

          if allowed_types.present? && !allowed_types.include?(obj.class.name)
            raise ArgumentError.new("#{obj.class.name} is not an allowed type for #{name}. Allowed types: #{allowed_types.join(', ')}")
          end

          obj.embedded = true
          raw = obj.serialized_attributes
          raw.delete('id') if raw['id'].blank?
          raw['type'] = obj.class.name

          embedded_objects << obj
          serialized << raw
        end

        write_attribute(storage_key, serialized)
        instance_variable_set(instance_var, embedded_objects)
      end
    end

    def define_standard_embeds_many_reader(name, storage_key, instance_var, klass_name)
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
    end

    def define_standard_embeds_many_writer(name, storage_key, instance_var, _klass_name)
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
  end
end
