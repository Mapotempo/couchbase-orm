# frozen_string_literal: true

module CouchbaseOrm
  module Embedded
    extend ActiveSupport::Concern

    class_methods do
      def embedded
        @embedded ||= begin
          inherited_embedded = superclass.respond_to?(:embedded) ? superclass.embedded : {}
          deep_dup_embedded(inherited_embedded)
        end
      end

      def set_embedded(name, config)
        embedded[name] = config
        @key_to_embedded_name = nil # Invalidate memo
      end

      def key_to_embedded_name
        @key_to_embedded_name ||= embedded.map { |name, config| [config[:key], name] }.to_h
      end

      private

      def deep_dup_embedded(original)
        original.transform_values(&:dup)
      end
    end

    # rubocop:disable Metrics/BlockLength
    included do
      def dup
        copy = super
        copy.cleanup_embedded_memoization!
        copy
      end

      def serializable_hash(options = {})
        result = super(options)
                
        result[:type] = self.class.name if polymorphic_embedded?
        
        result.delete(:id) if embedded? && result[:id].blank?
        result.delete('id') if embedded? && result['id'].blank?
        
        result
      end

      protected

      def embedded?
        !!@_embedded
      end

      def embedded=(value)
        @_embedded = value
      end

      def polymorphic_embedded?
        !!@_polymorphic_embedded
      end

      def polymorphic_embedded=(value)
        @_polymorphic_embedded = value
      end

      def cleanup_embedded_memoization!
        self.class.embedded.each_value do |value|
          ivar = value[:instance_var]
          remove_instance_variable(ivar) if instance_variable_defined?(ivar)
        end
      end
      # rubocop:enable Metrics/BlockLength
    end
  end
end
