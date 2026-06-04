# frozen_string_literal: true

module CouchbaseOrm
  class IndexSchema
    autoload :Dumper, 'couchbase-orm/index_schema/dumper'
    autoload :Loader, 'couchbase-orm/index_schema/loader'

    class DSL
      def initialize(indexes)
        @indexes = indexes
      end

      def add_index(name, keys:, where: nil, num_replica: nil, defer_build: false)
        index_definition = CouchbaseOrm::IndexDefinition.new(
          name: name,
          keys: keys,
          where: where,
          defer_build: defer_build,
          num_replica: num_replica
        )
        @indexes[index_definition.name] = index_definition
      end

      def remove_index(name)
        @indexes.delete(name.to_sym)
      end

      def rename_index(old_name, new_name)
        index_definition = @indexes.delete(old_name.to_sym)
        return unless index_definition

        renamed_index = CouchbaseOrm::IndexDefinition.new(
          name: new_name,
          keys: index_definition.keys,
          where: index_definition.where,
          defer_build: index_definition.defer_build,
          num_replica: index_definition.num_replica
        )
        @indexes[renamed_index.name] = renamed_index
      end
    end

    class << self
      def define(version: nil, &block)
        indexes = {}
        DSL.new(indexes).instance_eval(&block) if block

        if @define_handler
          @define_handler.call(indexes, version)
        else
          indexes
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
