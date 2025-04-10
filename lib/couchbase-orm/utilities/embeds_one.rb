# frozen_string_literal: true

module CouchbaseOrm
  module EmbedsOne
    def embeds_one(name, class_name: nil, store_as: nil, validate: true)
      storage_key = (store_as || name).to_sym
      attribute storage_key, :hash, default: nil

      instance_var = "@__assoc_#{name}"
      class_name = (class_name || name.to_s.camelize).constantize

      set_embedded(name, {
        type: :one,
        class_name: class_name,
        key: storage_key,
        name: name,
        instance_var: instance_var,
      })

      validates_embedded(name) if validate

      define_method(name) do
        return self.instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

        raw = self.read_attribute(storage_key)
        return self.instance_variable_set(instance_var, nil) unless raw.present?

        obj = class_name.new(raw)
        obj.embedded = true
        self.instance_variable_set(instance_var, obj)
      end

      define_method("#{name}=") do |val|
        if val.nil?
          self.write_attribute(storage_key, nil)
          instance_variable_set(instance_var, nil)
          next
        end

        obj = val.is_a?(class_name) ? val : class_name.new(val)
        obj.embedded = true
        raw = obj.serialized_attributes
        raw.delete('id') if raw['id'].blank?
        self.write_attribute(storage_key, raw)
        instance_variable_set(instance_var, obj)
      end

      define_method(:"#{name}_reset") do
        remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
      end
    end
  end
end
