# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

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
      super || attributes.key?(name.to_s.reader)
    end

    private

      # Override private _assign_attribute to accept dynamic attribute
      #
      # @param [ String ] name of attribute
      # @param [ Object ] value of attribute
      #
      # @return [ Object ] value of attribute
    def _assign_attribute(name, value)
      setter = name.to_s.writer
      responds = setter == 'id=' || respond_to?(setter)
      if responds
        public_send(setter, value)
      else
        type = define_attribute_type(value)
        type = if type == :array
                 item_type = define_attribute_type(value.first)
                 ActiveModel::Type.lookup(type, type: item_type)
               else
                 ActiveModel::Type.lookup(type)
               end
        @attributes[name] = ActiveModel::Attribute.from_database(name, value, type)
      end
    end

    # Determines the attribute type based on the value provided.
    #
    # This method converts the class of the value to a symbol and handles special cases
    # for `ActiveSupport::HashWithIndifferentAccess`, booleans, and nil values.
    #
    # @param [Object] value The value whose type needs to be determined.
    # @return [Symbol] The determined type of the attribute.
    #
    # @example Determining types of various values
    #   define_attribute_type(123)                                   # => :big_integer
    #   define_attribute_type("Hello")                               # => :string
    #   define_attribute_type(true)                                  # => :boolean
    #   define_attribute_type(false)                                 # => :boolean
    #   define_attribute_type(nil)                                   # => :raw
    #   define_attribute_type(ActiveSupport::HashWithIndifferentAccess.new) # => :hash
    def define_attribute_type(value)
      type = value.class.to_s.underscore.to_sym
      return :hash if type == :"active_support/hash_with_indifferent_access"
      return :boolean if type == :true_class
      return :boolean if type == :false_class
      return :raw if type == :nil_class
      return :big_integer if type == :integer

      type
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
      getter = attr.reader

      return super if getter == 'id'
      return super if attributes.key?(getter)

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
