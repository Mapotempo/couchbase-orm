# frozen_string_literal: true

module CouchbaseOrm
  class IndexSchema
    class Loader
      def initialize(path: CouchbaseOrm.config.index.schema_path, migration_class: CouchbaseOrm::IndexMigration)
        @path = path
        @migration_class = migration_class
      end

      def load
        definition, version = read_definition
        apply_definition(definition)
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

        definition.indexes.keys.sort.each do |name|
          options = definition.indexes[name]
          migration.execute_add_index(
            name,
            keys: options[:keys],
            where: options[:where],
            num_replica: options[:num_replica],
            defer_build: options.fetch(:defer_build, false)
          )
          deferred_indexes << name if options[:defer_build]
        end

        migration.execute_build_indexes(deferred_indexes.sort) if deferred_indexes.any?
      end
    end
  end
end
