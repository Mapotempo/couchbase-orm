# frozen_string_literal: true

module CouchbaseOrm
  class PolymorphicTypeValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      allowed_types = options[:allowed_types]
      return if allowed_types.blank?
      return if value.nil?

      # Handle array of embedded objects
      if value.is_a?(Array)
        value.each_with_index do |obj, i|
          next if obj.nil?
          next if allowed_types.include?(obj.class.name)

          record.errors.add(
            attribute,
            "item ##{i} (#{obj.class.name}) is not an allowed type. Allowed types: #{allowed_types.join(', ')}"
          )
        end
      else
        # Handle single embedded object
        return if allowed_types.include?(value.class.name)

        record.errors.add(
          attribute,
          "#{value.class.name} is not an allowed type. Allowed types: #{allowed_types.join(', ')}"
        )
      end
    end
  end
end
