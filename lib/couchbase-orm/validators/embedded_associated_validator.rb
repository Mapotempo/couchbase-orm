# frozen_string_literal: true

module CouchbaseOrm
  class EmbeddedAssociatedValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      if value.is_a?(Array)
        value.each_with_index do |v, i|
          next if v.valid?

          record.errors.add(attribute, "item ##{i} is invalid")
          v.errors.each do |*args|
            if args.first.respond_to?(:attribute) # rails 7
              error = args.first
              key = "#{attribute}_#{i}_#{error.attribute}".to_sym
              msg = error.message
            else # Rails 5/6
              k, msg = args
              key = "#{attribute}_#{i}_#{k}".to_sym
            end
            record.errors.add(key, msg)
          end
        end
      else
        return if value.nil? || value.valid?

        record.errors.add(attribute, 'is invalid')
        value.errors.each do |*args|
          if args.first.respond_to?(:attribute) # rails 7
            error = args.first
            key = "#{attribute}_#{error.attribute}".to_sym
            msg = error.message
          else # Rails 5/6
            k, msg = args
            key = "#{attribute}_#{k}".to_sym
          end
          record.errors.add(key, msg)
        end
      end
    end
  end
end
