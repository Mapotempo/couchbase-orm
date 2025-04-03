# frozen_string_literal: true

module CouchbaseOrm
  module EmbedsMany
    def embeds_many(name, class_name: nil)
      attribute name, :array, type: :hash, default: []

      instance_var = "@__assoc_#{name}"
      class_name = (class_name || name.to_s.singularize.camelize).constantize

      embedded[name] = {
        type: :many,
        class_name: class_name,
        key: name,
        name: name,
        instance_var: instance_var,
      }

      define_method(name) do
        return self.instance_variable_get(instance_var) if instance_variable_defined?(instance_var)

        embedded_objects = self.read_attribute(name).map do |raw|
          obj = class_name.new(raw)
          obj.instance_variable_set(:@_embedded, true)
          obj
        end

        self.instance_variable_set(instance_var, embedded_objects)
      end

      define_method("#{name}=") do |val|
        embedded_objects = []
        serialized = []

        val.each do |v|
          obj = v.is_a?(class_name) ? v : class_name.new(v)
          obj.instance_variable_set(:@_embedded, true)
          embedded_objects << obj
          serialized << obj.serialized_attributes.merge(type: self.class.design_document)
        end

        write_attribute(name, serialized)
        instance_variable_set(instance_var, embedded_objects)
      end

      define_method(:"#{name}_reset") do
        remove_instance_variable(instance_var) if instance_variable_defined?(instance_var)
      end
    end
  end
end
