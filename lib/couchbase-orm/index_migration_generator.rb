# frozen_string_literal: true

require 'fileutils'
require 'active_support/core_ext/string/inflections'

module CouchbaseOrm
  class IndexMigrationGenerator
    def initialize(path: CouchbaseOrm.config.index.migrations_path, now: Time.now)
      @path = path
      @now = now
    end

    def generate(name)
      raise ArgumentError, 'Migration name is required' if name.to_s.strip.empty?

      timestamp = @now.utc.strftime('%Y%m%d%H%M%S')
      underscored = name.to_s.underscore
      class_name = name.to_s.camelize
      file_path = File.join(@path, "#{timestamp}_#{underscored}.rb")

      FileUtils.mkdir_p(@path)
      File.write(file_path, migration_template(class_name))
      file_path
    end

    private

    def migration_template(class_name)
      <<~RUBY
        class #{class_name} < CouchbaseOrm::IndexMigration
          def change
          end
        end
      RUBY
    end
  end
end