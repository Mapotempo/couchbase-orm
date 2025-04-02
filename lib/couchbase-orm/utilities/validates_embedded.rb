# frozen_string_literal: true

module CouchbaseOrm
  module ValidatesEmbedded
    extend ActiveSupport::Concern

    class_methods do
      def validates_embedded(*attrs)
        validates_with CouchbaseOrm::EmbeddedAssociatedValidator, _merge_attributes(attrs)
      end
    end
  end
end
