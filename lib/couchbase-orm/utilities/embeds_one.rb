# frozen_string_literal: true

module CouchbaseOrm
  module EmbedsOne
    def embeds_one(name, class_name: nil, store_as: nil, validate: true)
      storage_key = (store_as || name).to_sym
      attribute storage_key, :hash, default: nil

      instance_var = "@__assoc_#{name}"
      klass_name = (class_name || name.to_s.camelize)

      set_embedded(name, {
        type: :one,
        class_name: klass_name, # keep as string to delay resolution
        key: storage_key,
        name: name,
        instance_var: instance_var,
      })

      validates_embedded(name) if validate

      # Helper to lazy-resolve class when needed
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

      define_method("#{name}=") do |val|
        if val.nil?
          write_attribute(storage_key, nil)
          instance_variable_set(instance_var, nil)
          next
        end

        klass = send("_resolve_embedded_class_for_#{name}")
        obj = val.is_a?(klass) ? val : klass.new(val)
        obj.embedded = true

        raw = obj.serialized_attributes
        raw.delete('id') if raw['id'].blank?

        write_attribute(storage_key, raw)
        instance_variable_set(instance_var, obj)
      end

      define_method(:"#{name}_reset") do
        remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
      end
    end
  end
end
