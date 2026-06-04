# frozen_string_literal: true

require 'json'
require 'couchbase'

module CouchbaseOrm
  class IndexMigration
    autoload :CommandRecorder, 'couchbase-orm/index_migration/command_recorder'
    autoload :IndexIntrospector, 'couchbase-orm/index_migration/index_introspector'
    autoload :IndexStateFetcher, 'couchbase-orm/index_migration/index_state_fetcher'
    autoload :MigrationGenerator, 'couchbase-orm/index_migration/migration_generator'
    autoload :Operations, 'couchbase-orm/index_migration/operations'
    autoload :QueryBuilder, 'couchbase-orm/index_migration/query_builder'

    class IrreversibleMigration < StandardError; end

    def migrate(direction)
      direction = direction.to_sym
      raise ArgumentError.new('direction must be :up or :down') unless %i[up down].include?(direction)

      if direction == :up
        run_up
      else
        run_down
      end
    end

    def add_index(name, keys:, where: nil, num_replica: nil, defer_build: false)
      index_definition = CouchbaseOrm::IndexDefinition.new(
        name: name,
        keys: keys,
        where: where,
        defer_build: defer_build,
        num_replica: num_replica
      )
      execute_operation(Operations::CreateIndex.new(index_definition))
    end

    def remove_index(name)
      execute_operation(Operations::RemoveIndex.new(name))
    end

    def build_indexes(*index_names)
      options = index_names.last.is_a?(Hash) ? index_names.pop : {}
      unknown_keys = options.keys - [:wait]
      raise ArgumentError.new("Unknown option(s): #{unknown_keys.join(', ')}") if unknown_keys.any?

      execute_operation(Operations::BuildIndexes.new(index_names, wait: options.fetch(:wait, false)))
    end

    def execute_query(query)
      CouchbaseOrm::Connection.cluster.query(query, Couchbase::Options::Query.new)
    end

    def query_builder
      @query_builder ||= QueryBuilder.new(config: CouchbaseOrm.config.index)
    end

    def index_bucket
      bucket = CouchbaseOrm.config.index.effective_bucket
      raise ArgumentError.new('Missing index bucket configuration') if bucket.to_s.strip.empty?

      bucket
    end

    def wait_for_indexes_online(index_names)
      names = Array(index_names).map(&:to_s)

      loop do
        return if IndexStateFetcher.new.online?(self, index_bucket, names)

        sleep(1)
      end
    end

    private

    def run_up
      if method_overridden?(:up)
        up
      else
        change
      end
    end

    def run_down
      if method_overridden?(:down)
        down
      else
        recorder = CommandRecorder.new
        with_recorder(recorder) { change }
        recorder.replay_inverse(self)
      end
    end

    def execute_operation(operation)
      if @command_recorder
        @command_recorder.record(operation)
      else
        operation.execute(self)
      end
    end

    def with_recorder(recorder)
      @command_recorder = recorder
      yield
    ensure
      @command_recorder = nil
    end

    def method_overridden?(method_name)
      self.class.instance_method(method_name).owner != CouchbaseOrm::IndexMigration
    end

    def change
      raise NotImplementedError.new('Define change or up/down in your migration')
    end

    def up
      change
    end

    def down
      raise NotImplementedError.new('Define down for non-reversible migrations')
    end
  end
end
