# frozen_string_literal: true

module CouchbaseOrm
  module Extensions
    module String
      def reader
        delete_suffix('_before_type_cast').delete('=')
      end

      def writer
        delete_suffix('_before_type_cast') + '='
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
