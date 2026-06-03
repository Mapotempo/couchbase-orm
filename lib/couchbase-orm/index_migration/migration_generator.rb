# frozen_string_literal: true

require 'fileutils'
require 'active_support/core_ext/string/inflections'

module CouchbaseOrm
  class IndexMigration
    class MigrationGenerator
      DEFAULT_NAME = 'InitialIndexes'

      def initialize(path: CouchbaseOrm.config.index.migrations_path, now: Time.now)
        @path = path
        @now = now
      end

      def generate(index_definitions, name: DEFAULT_NAME)
        class_name = migration_class_name(name)
        timestamp = @now.utc.strftime('%Y%m%d%H%M%S')
        file_name = "#{timestamp}_#{class_name.underscore}.rb"
        file_path = File.join(@path, file_name)

        FileUtils.mkdir_p(@path)
        File.write(file_path, source_for(index_definitions, class_name: class_name))
        file_path
      end

      def source_for(index_definitions, class_name: DEFAULT_NAME)
        definitions = Array(index_definitions).sort_by(&:name)

        <<~RUBY
          class #{migration_class_name(class_name)} < CouchbaseOrm::IndexMigration
            def up
          #{up_body(definitions)}
            end

            def down
          #{down_body(definitions)}
            end
          end
        RUBY
      end

      private

      def migration_class_name(name)
        value = name.to_s.strip
        raise ArgumentError.new('Migration name is required') if value.empty?

        value.camelize
      end

      def up_body(definitions)
        lines = []

        definitions.each_with_index do |definition, index|
          lines.concat(add_index_lines(definition))
          lines << '' unless index == definitions.length - 1
        end

        if definitions.any?
          lines << ''
          lines.concat(build_indexes_lines(definitions))
        end

        indent(lines)
      end

      def down_body(definitions)
        lines = definitions.reverse.map { |definition| "remove_index :#{definition.name}" }
        indent(lines)
      end

      def add_index_lines(definition)
        lines = [
          'add_index(',
          "  :#{definition.name},",
          "  keys: #{ruby_array(definition.keys)},"
        ]
        lines << "  where: #{definition.where.inspect}," if definition.where
        lines << '  defer_build: true'
        lines << ')'
        lines
      end

      def build_indexes_lines(definitions)
        lines = ['build_indexes(']
        definitions.each_with_index do |definition, index|
          suffix = index == definitions.length - 1 ? '' : ','
          lines << "  :#{definition.name}#{suffix}"
        end
        lines << ')'
        lines
      end

      def ruby_array(values)
        "[#{Array(values).map { |value| ruby_value(value) }.join(', ')}]"
      end

      def ruby_value(value)
        value.is_a?(Symbol) ? ":#{value}" : value.inspect
      end

      def indent(lines)
        Array(lines).map { |line| "    #{line}" }.join("\n")
      end
    end
  end
end
