# frozen_string_literal: true

module CouchbaseOrm
  class EmbeddedAssociatedValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      if value.is_a?(Array)
        value.each_with_index do |v, i|
          next if v.valid?

          record.errors.add(attribute, "item ##{i} is invalid")
          v.errors.each do |k, msg|
            record.errors.add("#{attribute}_#{i}_#{k}".to_sym, msg)
          end
        end
      else
        return if value.nil? || value.valid?

        record.errors.add(attribute, "is invalid")
        value.errors.each do |k, msg|
          record.errors.add("#{attribute}_#{k}".to_sym, msg)
        end
      end
    end
  end
end
