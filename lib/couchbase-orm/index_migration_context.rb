# frozen_string_literal: true

require 'active_support/core_ext/string/inflections'

module CouchbaseOrm
  class IndexMigrationContext
    Migration = Struct.new(:version, :name, :klass, :path, keyword_init: true)

    def initialize(path: CouchbaseOrm.config.index.migrations_path)
      @path = path
    end

    def migrations
      migration_files.map do |file|
        version, underscored_name = parse_file_name(file)
        require File.expand_path(file)
        class_name = underscored_name.camelize

        Migration.new(
          version: version,
          name: class_name,
          klass: Object.const_get(class_name),
          path: file
        )
      end
    end

    def pending_migrations(executed_versions)
      executed_set = Array(executed_versions).map(&:to_s)
      migrations.reject { |migration| executed_set.include?(migration.version) }
    end

    def find(version)
      migrations.find { |migration| migration.version == version.to_s }
    end

    private

    def migration_files
      Dir[File.join(@path, '*.rb')].sort
    end

    def parse_file_name(file)
      match = File.basename(file).match(/\A(\d+)_(.+)\.rb\z/)
      raise ArgumentError, "Invalid migration file name: #{file}" unless match

      [match[1], match[2]]
    end
  end
end