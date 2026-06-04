# frozen_string_literal: true

module CouchbaseOrm
  class IndexSchema
    autoload :Definition, 'couchbase-orm/index_schema/definition'
    autoload :Dumper, 'couchbase-orm/index_schema/dumper'
    autoload :Loader, 'couchbase-orm/index_schema/loader'

    class DSL
      def initialize(definition)
        @definition = definition
      end

      def add_index(name, keys:, where: nil, num_replica: nil, defer_build: false)
        @definition.add_index(name, keys: keys, where: where, num_replica: num_replica, defer_build: defer_build)
      end

      def remove_index(name)
        @definition.remove_index(name)
      end

      def rename_index(old_name, new_name)
        @definition.rename_index(old_name, new_name)
      end
    end

    class << self
      def define(version: nil, &block)
        definition = Definition.new
        DSL.new(definition).instance_eval(&block) if block

        if @define_handler
          @define_handler.call(definition, version)
        else
          definition
        end
      end

      def with_define_handler(handler)
        previous_handler = @define_handler
        @define_handler = handler
        yield
      ensure
        @define_handler = previous_handler
      end
    end
  end
end
