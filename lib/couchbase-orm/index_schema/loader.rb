# frozen_string_literal: true

module CouchbaseOrm
  class IndexSchema
    class Loader
      def initialize(path: CouchbaseOrm.config.index.schema_path, migration_class: CouchbaseOrm::IndexMigration)
        @path = path
        @migration_class = migration_class
      end

      def load
        indexes, version = read_definition
        apply_definition(indexes)
        version
      end

      private

      def read_definition
        captured_definition = nil
        captured_version = nil

        CouchbaseOrm::IndexSchema.with_define_handler(lambda do |definition, version|
          captured_definition = definition
          captured_version = version
        end) do
          Kernel.load(File.expand_path(@path))
        end

        raise ArgumentError.new("Schema file did not define CouchbaseOrm::IndexSchema: #{@path}") unless captured_definition

        [captured_definition, captured_version]
      rescue Errno::ENOENT
        raise ArgumentError.new("Schema file not found: #{@path}")
      end

      def apply_definition(definition)
        migration = @migration_class.new
        deferred_indexes = []
        create_operation_class = @migration_class::Operations::CreateIndex
        build_operation_class = @migration_class::Operations::BuildIndexes

        definition.keys.sort.each do |name|
          index_definition = definition[name]
          create_operation_class.new(index_definition).execute(migration)
          deferred_indexes << name if index_definition.defer_build
        end

        build_operation_class.new(deferred_indexes.sort).execute(migration) if deferred_indexes.any?
      end
    end
  end
end
