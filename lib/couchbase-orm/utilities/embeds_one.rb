# frozen_string_literal: true

module CouchbaseOrm
  module EmbedsOne
    def embeds_one(name, class_name: nil, store_as: nil, validate: true, polymorphic: false)
      storage_key = (store_as || name).to_sym
      attribute storage_key, :hash, default: nil

      instance_var = "@__assoc_#{name}"
      klass_name = (class_name || name.to_s.camelize)

      # Handle polymorphic parameter: can be true, false, or array of allowed types
      is_polymorphic = polymorphic.is_a?(Array) || polymorphic == true
      allowed_types = polymorphic.is_a?(Array) ? polymorphic.map { |t| t.to_s.camelize } : nil

      set_embedded(name, {
        type: :one,
        class_name: klass_name,
        key: storage_key,
        name: name,
        instance_var: instance_var,
        polymorphic: is_polymorphic,
        allowed_types: allowed_types,
      })

      validates_embedded(name) if validate

      if is_polymorphic
        define_polymorphic_embeds_one_reader(name, storage_key, instance_var)
        define_polymorphic_embeds_one_writer(name, storage_key, instance_var, allowed_types)
      else
        define_standard_embeds_one_reader(name, storage_key, instance_var, klass_name)
        define_standard_embeds_one_writer(name, storage_key, instance_var, klass_name)
      end

      define_method(:"#{name}_reset") do
        remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
      end
    end

    private

    def define_polymorphic_embeds_one_reader(name, storage_key, instance_var)
      define_method(name) do
        return instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

        raw = read_attribute(storage_key)
        return instance_variable_set(instance_var, nil) unless raw.present?

        type = raw['type'] || raw[:type]
        return instance_variable_set(instance_var, nil) unless type.present?

        klass = type.constantize
        attrs = raw.dup
        attrs.delete('type')
        attrs.delete(:type)
        obj = klass.new(attrs)
        obj.embedded = true
        instance_variable_set(instance_var, obj)
      end
    end

    def define_polymorphic_embeds_one_writer(name, storage_key, instance_var, allowed_types)
      define_method("#{name}=") do |val|
        if val.nil?
          write_attribute(storage_key, nil)
          instance_variable_set(instance_var, nil)
          return
        end

        obj = if val.is_a?(Hash)
                type_name = val[:type] || val['type']
                raise ArgumentError.new("Cannot infer type from Hash for polymorphic embeds_one. Include 'type' key with class name.") unless type_name.present?

                klass = type_name.to_s.camelize.constantize
                attrs = val.dup
                attrs.delete(:type)
                attrs.delete('type')
                klass.new(attrs)
              else
                val
              end

        if allowed_types.present? && !allowed_types.include?(obj.class.name)
          raise ArgumentError.new("#{obj.class.name} is not an allowed type for #{name}. Allowed types: #{allowed_types.join(', ')}")
        end

        obj.embedded = true
        raw = obj.serialized_attributes
        raw.delete('id') if raw['id'].blank?
        raw['type'] = obj.class.name

        write_attribute(storage_key, raw)
        instance_variable_set(instance_var, obj)
      end
    end

    def define_standard_embeds_one_reader(name, storage_key, instance_var, klass_name)
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

        raw = read_attribute(storage_key)
        return instance_variable_set(instance_var, nil) unless raw.present?

        klass = send("_resolve_embedded_class_for_#{name}")
        obj = klass.new(raw)
        obj.embedded = true
        instance_variable_set(instance_var, obj)
      end
    end

    def define_standard_embeds_one_writer(name, storage_key, instance_var, _klass_name)
      define_method("#{name}=") do |val|
        if val.nil?
          write_attribute(storage_key, nil)
          instance_variable_set(instance_var, nil)
          return
        end

        klass = send("_resolve_embedded_class_for_#{name}")
        obj = val.is_a?(klass) ? val : klass.new(val)
        obj.embedded = true

        raw = obj.serialized_attributes
        raw.delete('id') if raw['id'].blank?

        write_attribute(storage_key, raw)
        instance_variable_set(instance_var, obj)
      end
    end
  end
end
