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
        definition = Definition.new
        migrations = @context.migrations

        migrations.each do |migration_def|
          replay_migration(migration_def, definition)
        end

        schema_source = source_for(definition, version: migrations.max_by(&:version)&.version)

        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, schema_source)
        @path
      end

      def source_for(definition, version: nil)
        lines = []
        lines << definition_header(version)

        index_names = definition.indexes.keys.sort
        index_names.each_with_index do |name, index|
          lines.concat(index_lines(name, definition.indexes[name]))
          lines << '' unless index == index_names.length - 1
        end

        lines << 'end'
        "#{lines.join("\n")}\n"
      end

      private

      def replay_migration(migration_def, definition)
        migration = migration_def.klass.new

        migration.singleton_class.class_eval do
          define_method(:add_index) do |name, keys:, where: nil, num_replica: nil, defer_build: false|
            definition.add_index(name, keys: keys, where: where, num_replica: num_replica, defer_build: defer_build)
          end

          define_method(:remove_index) do |name|
            definition.remove_index(name)
          end

          define_method(:rename_index) do |old_name, new_name|
            definition.rename_index(old_name, new_name)
          end

          define_method(:build_indexes) do |*_index_names, **_options|
            nil
          end
        end

        migration.migrate(:up)
      end

      def definition_header(version)
        if version
          "CouchbaseOrm::IndexSchema.define(version: #{version}) do"
        else
          'CouchbaseOrm::IndexSchema.define do'
        end
      end

      def index_lines(name, options)
        lines = ["  add_index :#{name},"]

        option_lines = ["keys: #{ruby_array(options[:keys])}"]
        option_lines << "where: #{options[:where].inspect}" if options.key?(:where)
        option_lines << "num_replica: #{options[:num_replica]}" if options.key?(:num_replica)
        option_lines << 'defer_build: true' if options[:defer_build]

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
        value.is_a?(Symbol) ? ":#{value}" : value.inspect
      end
    end
  end
end
