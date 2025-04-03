# frozen_string_literal: true

module CouchbaseOrm
  module AttributeProcessing
    extend ActiveSupport::Concern

    class_methods do
      def embedded
        @embedded ||= {}
      end

      def set_embedded(name, config)
        embedded[name] = config
        @key_to_embedded_name = nil # Invalidate memo
      end

      def key_to_embedded_name
        @key_to_embedded_name ||= embedded.map { |name, config| [config[:key], name] }.to_h
      end
    end

    def _assign_attributes(attrs)
      key_to_name = self.class.key_to_embedded_name
      embedded_attrs = []
      normal_attrs = []

      attrs.each do |k, v|
        sym_key = k.to_sym
        if key_to_name.key?(sym_key)
          embedded_attrs << [key_to_name[sym_key], v]
        else
          normal_attrs << [k, v]
        end
      end

      super(normal_attrs)
      assign_embedded_attributes(embedded_attrs)
    end

    private

    def assign_embedded_attributes(attrs)
      attrs.each do |name, value|
        embedded = self.class.embedded[name.to_sym]

        if embedded[:type] == :one
          if value.is_a?(embedded[:class_name])
            _assign_attribute(name, value)
          else
            write_attribute(embedded[:key], value)
          end
        else
          tab = Array(value)
          if tab.first.is_a?(embedded[:class_name])
            _assign_attribute(name, tab)
          else
            write_attribute(embedded[:key], tab)
          end
        end
      end
    end
  end
end
