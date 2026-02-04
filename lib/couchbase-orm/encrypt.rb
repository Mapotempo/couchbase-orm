# frozen_string_literal: true, encoding: ASCII-8BIT
# frozen_string_literal: true

module CouchbaseOrm
  module Encrypt
    def encode_encrypted_attributes
      attributes.map do |key, value|
        type = self.class.attribute_types[key.to_s]
        if type.is_a?(CouchbaseOrm::Types::Encrypted)
          next unless value
          raise "Can not serialize value #{value} of type '#{value.class}' for Tanker encrypted attribute" unless value.is_a?(String)

          ["encrypted$#{key}", {
              alg: type.alg,
              ciphertext: value
          }]
        else
          [key, value]
        end
      end.compact.to_h
    end

    def decode_encrypted_attributes(attributes)
      attributes.map do |key, value|
        key = key.to_s
        if key.start_with?('encrypted$')
          key = key.gsub('encrypted$', '')
          value = value.with_indifferent_access[:ciphertext]
        end
        [key, value]
      end.to_h
    end

    # @deprecated This validation is now handled in the base serialization flow.
    #   Overriding as_json in the Encrypt module is deprecated and may be removed in future versions.
    # def as_json(*args, **kwargs)
    #  super(*args, **kwargs).tap do |result|
    #    result.each do |key, value|
    #      type = self.class.attribute_types[key.to_s]
    #      if type.is_a?(CouchbaseOrm::Types::Encrypted) && value && !value.is_a?(String)
    #        raise "Can not serialize value #{value} of type '#{value.class}' for encrypted attribute"
    #      end
    #    end
    #  end
    # end
  end
end
