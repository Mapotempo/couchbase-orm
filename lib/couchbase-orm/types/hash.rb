# frozen_string_literal: true

module CouchbaseOrm
  module Types
    class Hash < ActiveModel::Type::Value
      def cast(value)
        return nil if value.nil?
        return value if value.is_a?(ActiveSupport::HashWithIndifferentAccess)
        return value.with_indifferent_access if value.is_a?(::Hash)

        raise ArgumentError.new("Hash: #{value.inspect} (#{value.class}) is not supported for cast")
      end

      def serialize(value)
        return nil if value.nil?
        return value.as_json if value.is_a?(ActiveSupport::HashWithIndifferentAccess)
        return value.with_indifferent_access.as_json if value.is_a?(::Hash)

        raise ArgumentError.new("Hash: #{value.inspect} (#{value.class}) is not supported for serialize")
      end
    end
  end
end
