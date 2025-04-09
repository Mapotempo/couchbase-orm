# frozen_string_literal: true

module CouchbaseOrm
  module EmbedsMany
    def embeds_many(name, class_name: nil, store_as: nil, validate: true)
      storage_key = (store_as || name).to_sym
      attribute storage_key, :array, type: :hash, default: []

      instance_var = "@__assoc_#{name}"
      class_name = (class_name || name.to_s.singularize.camelize).constantize

      set_embedded(name, {
        type: :many,
        class_name: class_name,
        key: storage_key,
        name: name,
        instance_var: instance_var,
      })

      validates_embedded(name) if validate

      define_method(name) do
        return self.instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

        embedded_objects = self.read_attribute(storage_key).map do |raw|
          obj = class_name.new(raw)
          obj.embedded = true
          obj
        end

        self.instance_variable_set(instance_var, embedded_objects)
      end

      define_method("#{name}=") do |val|
        embedded_objects = []
        serialized = []

        val.each do |v|
          obj = v.is_a?(class_name) ? v : class_name.new(v)
          obj.embedded = true
          embedded_objects << obj
          raw = obj.serialized_attributes
          raw.delete('id') if raw['id'].blank?
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
