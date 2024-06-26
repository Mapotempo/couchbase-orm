# frozen_string_literal: true

module CouchbaseOrm
  module Extensions
    module String
      def reader
        delete('=').sub(/_before_type_cast\z/, '')
      end

      def writer
        sub(/_before_type_cast\z/, '') + '='
      end

      def writer?
        include?('=')
      end

      def before_type_cast?
        ends_with?('_before_type_cast')
      end

      def valid_method_name?
        /[@$"-]/ !~ self
      end
    end
  end
end

::String.include CouchbaseOrm::Extensions::String
