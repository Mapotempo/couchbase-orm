# frozen_string_literal: true

module CouchbaseOrm
  module Types
    class Raw < ActiveModel::Type::Value
      def cast(values)
        values
      end

      def serialize(values)
        values
      end
    end
  end
end
