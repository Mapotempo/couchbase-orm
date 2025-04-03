# frozen_string_literal: true

module CouchbaseOrm
  module AttributeProcessing
    extend ActiveSupport::Concern

    class_methods do
      def embedded
        @embedded ||= {}
      end
    end

    def _assign_attributes(attrs)
      embedded_attrs, normal_attrs = attrs.partition { |k, _| self.class.embedded.include?(k.to_sym) }

      super(normal_attrs)

      assign_embedded_attributes(embedded_attrs)
    end

    private

    def assign_embedded_attributes(attrs)
      attrs.each do |key, value|
        embedded = self.class.embedded[key.to_sym]

        if embedded[:type] == :one
          if value.is_a?(embedded[:class_name])
            _assign_attribute(key, value)
          else
            write_attribute(key, value)
          end
        else
          tab = Array(value)
          if Array(value).first.is_a?(embedded[:class_name])
            _assign_attribute(key, tab)
          else
            write_attribute(key, tab)
          end
        end
      end
    end
  end
end
