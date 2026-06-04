# frozen_string_literal: true

module CouchbaseOrm
  class IndexMigrator
    class << self
      def migrate(**options)
        new(**options).migrate
      end

      def cleanup(**options)
        new(**options).cleanup
      end

      def rollback(**options)
        new(**options).rollback
      end

      def status(**options)
        new(**options).status
      end

      def adopt(**options)
        new(**options).adopt
      end
    end

    def initialize(context: IndexMigrationContext.new, schema_migration: IndexSchemaMigration.new, out: nil)
      @context = context
      @schema_migration = schema_migration
      @out = out || $stdout
    end

    def migrate
      @context.pending_migrations(@schema_migration.versions).each do |migration_def|
        migration = migration_def.klass.new
        migration.migrate(:up)
        @schema_migration.add_version(migration_def.version)
      end
    end

    def rollback
      version = @schema_migration.versions.max
      return nil unless version

      migration_def = @context.find(version)
      raise ArgumentError.new("Migration file not found for version #{version}") unless migration_def

      migration = migration_def.klass.new
      migration.migrate(:down)
      @schema_migration.remove_version(version)
      version
    end

    def status
      executed_versions = @schema_migration.versions
      lines = @context.migrations.map do |migration_def|
        state = executed_versions.include?(migration_def.version) ? 'up' : 'down'
        "#{state.ljust(6)} #{migration_def.version} #{migration_def.name}"
      end

      @out.puts(lines.join("\n")) unless lines.empty?
      lines
    end

    def adopt
      migration_def = @context.migrations.max_by(&:version)
      return nil unless migration_def

      @schema_migration.add_version(migration_def.version)
      migration_def.version
    end

    def cleanup
      names = IndexMigration::IndexIntrospector.new.indexes.map { |row| row[:name] }.sort
      migration = IndexMigration.new
      names.each { |name| migration.remove_index(name) }
      names
    end
  end
end
