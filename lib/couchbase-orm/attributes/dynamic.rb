# frozen_string_literal: true, encoding: ASCII-8BIT

module CouchbaseOrm
    module AttributesDynamic
        extend ActiveSupport::Concern

        # Override respond_to? so it responds properly for dynamic attributes.
        #
        # @example Does this object respond to the method?
        #   person.respond_to?(:title)
        #
        # @param [ Array ] name The name of the method.
        # @param [ true | false ] include_private
        #
        # @return [ true | false ] True if it does, false if not.
        def respond_to?(name, include_private = false)
            super || attributes&.key?(name.to_s.reader)
        end

        private

        # Override private _assign_attribute to accept dynamic attribute
        #
        # @param [ String ] name of attribute
        # @param [ Object ] value of attribute
        #
        # @return [ Object ] value of attribute
        def _assign_attribute(name, value)
            responds = name.reader == 'id' || respond_to?(name.writer)
            if responds
                public_send(name.writer, value)
            else
                type = value.class.to_s.underscore.to_sym
                type = :hash if type == :"active_support/hash_with_indifferent_access"
                type = ActiveModel::Type.lookup(type)
                @attributes[name] = ActiveModel::Attribute.from_database(name, value, type)
            end
        end

        # Define a reader method  for a dynamic attribute.
        #
        # @example Define a reader method.
        #   model.define_dynamic_reader(:field)
        #
        # @param [ String ] name The name of the field.
        def define_dynamic_reader(name)
            return unless name.valid_method_name?

            instance_eval do
                define_singleton_method(name) do
                    @attributes[getter].value
                end
            end
        end

        # Define a writer method for a dynamic attribute.
        #
        # @example Define a writer method.
        #   model.define_dynamic_writer(:field)
        #
        # @param [ String ] name The name of the field.
        def define_dynamic_writer(name)
            return unless name.valid_method_name?

            instance_eval do
                define_singleton_method("#{name}=") do |value|
                    @attributes.write_from_user(name, value)
                    value
                end
            end
        end

        # Used for allowing accessor methods for dynamic attributes.
        #
        # @api private
        #
        # @example Call through method_missing.
        #   document.method_missing(:test)
        #
        # @param [ String | Symbol ] name The name of the method.
        # @param [ Object... ] *args The arguments to the method.
        #
        # @return [ Object ] The result of the method call.
        def method_missing(name, *args)
            attr = name.to_s
            return super unless attr.reader != 'id' && attributes.key?(attr.reader)

            getter = attr.reader
            if attr.writer?
                define_dynamic_writer(getter)
                @attributes.write_from_user(getter, args.first)
                args.first
            else
                define_dynamic_reader(getter)
                @attributes[getter].value
            end
        end
    end
end