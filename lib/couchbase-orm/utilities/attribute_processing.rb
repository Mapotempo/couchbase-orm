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
  end
end
