# frozen_string_literal: true

module CouchbaseOrm
  module Embedded
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

    included do
      def dup
        copy = super
        copy.cleanup_embedded_memoization!
        copy
      end

      protected

      def embedded?
        !!@_embedded
      end

      def embedded=(value)
        @_embedded = value
      end

      def cleanup_embedded_memoization!
        self.class.embedded.each_value do |value|
          ivar = value[:instance_var]
          remove_instance_variable(ivar) if instance_variable_defined?(ivar)
        end
      end
    end
  end
end
