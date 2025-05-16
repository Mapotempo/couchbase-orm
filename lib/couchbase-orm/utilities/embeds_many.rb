# frozen_string_literal: true

module CouchbaseOrm
  module EmbedsMany
    def embeds_many(name, class_name: nil, store_as: nil, validate: true)
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
      })

      validates_embedded(name) if validate

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

      define_method(:"#{name}_reset") do
        remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
      end
    end
  end
end
