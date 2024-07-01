# frozen_string_literal: true

require 'rails/generators/named_base'
require 'rails/generators/active_model'

module CouchbaseOrm # :nodoc:
  module Generators # :nodoc:
    class Base < ::Rails::Generators::NamedBase # :nodoc:
      def self.source_root
        @_couchbase_source_root ||=
          File.expand_path("../#{base_name}/#{generator_name}/templates", __FILE__)
      end

      unless methods.include?(:module_namespacing)
        def module_namespacing(&block)
          yield if block
        end
      end
    end
  end
end
