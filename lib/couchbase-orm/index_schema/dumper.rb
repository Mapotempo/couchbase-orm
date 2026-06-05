# frozen_string_literal: true

require 'fileutils'

module CouchbaseOrm
  class IndexSchema
    class Dumper
      def initialize(context: CouchbaseOrm::IndexMigrationContext.new, path: CouchbaseOrm.config.index.schema_path)
        @context = context
        @path = path
      end

      def dump
        indexes = {}
        migrations = @context.migrations

        migrations.each do |migration_def|
          replay_migration(migration_def, indexes)
        end

        schema_source = source_for(indexes, version: migrations.max_by(&:version)&.version)

        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, schema_source)
        @path
      end

      def source_for(indexes, version: nil)
        lines = []
        lines << definition_header(version)

        index_names = indexes.keys.sort_by(&:to_s)
        index_names.each_with_index do |name, index|
          lines.concat(index_lines(indexes[name]))
          lines << '' unless index == index_names.length - 1
        end

        lines << 'end'
        "#{lines.join("\n")}\n"
      end

      private

      def replay_migration(migration_def, indexes)
        migration = migration_def.klass.new

        me = self
        migration.singleton_class.class_eval do
          me.send(:define_add_index, self, indexes)
          me.send(:define_remove_index, self, indexes)
          me.send(:define_rename_index, self, indexes)
          me.send(:define_build_indexes, self, indexes)
        end

        migration.migrate(:up)
      end

      def define_add_index(klass, indexes)
        klass.define_method(:add_index) do |name, keys:, where: nil, num_replica: nil, defer_build: false|
          index_definition = CouchbaseOrm::IndexDefinition.new(
            name: name,
            keys: keys,
            where: where,
            defer_build: defer_build,
            num_replica: num_replica
          )
          indexes[index_definition.name] = index_definition
        end
      end

      def define_remove_index(klass, indexes)
        klass.define_method(:remove_index) do |name|
          indexes.delete(CouchbaseOrm::IndexDefinition.normalize_name(name))
        end
      end

      def define_rename_index(klass, indexes)
        klass.define_method(:rename_index) do |old_name, new_name|
          index_definition = indexes.delete(CouchbaseOrm::IndexDefinition.normalize_name(old_name))
          next unless index_definition

          renamed_index = CouchbaseOrm::IndexDefinition.new(
            name: new_name,
            keys: index_definition.keys,
            where: index_definition.where,
            defer_build: index_definition.defer_build,
            num_replica: index_definition.num_replica
          )
          indexes[renamed_index.name] = renamed_index
        end
      end

      def define_build_indexes(klass, _indexes)
        klass.define_method(:build_indexes) do |*_index_names, **_options|
          nil
        end
      end

      def definition_header(version)
        if version
          "CouchbaseOrm::IndexSchema.define(version: #{version}) do"
        else
          'CouchbaseOrm::IndexSchema.define do'
        end
      end

      def index_lines(index_definition)
        lines = ["  add_index #{ruby_value(index_definition.name)},"]

        option_lines = ["keys: #{ruby_array(index_definition.keys)}"]
        option_lines << "where: #{index_definition.where.inspect}" if index_definition.where
        option_lines << "num_replica: #{index_definition.num_replica}" unless index_definition.num_replica.nil?
        option_lines << 'defer_build: true' if index_definition.defer_build

        option_lines.each_with_index do |line, index|
          suffix = index == option_lines.length - 1 ? '' : ','
          lines << "    #{line}#{suffix}"
        end

        lines
      end

      def ruby_array(values)
        "[#{Array(values).map { |value| ruby_value(value) }.join(', ')}]"
      end

      def ruby_value(value)
        value.inspect
      end
    end
  end
end
