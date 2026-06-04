# frozen_string_literal: true

require 'json'
require 'couchbase'

module CouchbaseOrm
  class IndexMigration
    autoload :IndexDefinition, 'couchbase-orm/index_migration/index_definition'
    autoload :IndexIntrospector, 'couchbase-orm/index_migration/index_introspector'
    autoload :MigrationGenerator, 'couchbase-orm/index_migration/migration_generator'

    class IrreversibleMigration < StandardError; end

    module Operations
      class AddIndex
        attr_reader :name, :keys, :where, :num_replica, :defer_build

        def initialize(name, keys:, where: nil, num_replica: nil, defer_build: false)
          @name = name
          @keys = keys
          @where = where
          @num_replica = num_replica
          @defer_build = defer_build
        end

        def execute(migration)
          migration.execute_add_index(name, keys: keys, where: where, num_replica: num_replica, defer_build: defer_build)
        end

        def inverse
          RemoveIndex.new(name)
        end
      end

      class BuildIndexes
        attr_reader :index_names, :wait

        def initialize(index_names, wait: false)
          @index_names = Array(index_names).flatten
          @wait = wait
          raise ArgumentError.new('At least one index name is required') if @index_names.empty?
        end

        def execute(migration)
          migration.execute_build_indexes(index_names, wait: wait)
        end

        def inverse
          raise IrreversibleMigration.new('build_indexes is not reversible. Define down explicitly.')
        end
      end

      class RemoveIndex
        attr_reader :name

        def initialize(name)
          @name = name
        end

        def execute(migration)
          migration.execute_remove_index(name)
        end

        def inverse
          raise IrreversibleMigration.new('remove_index is not reversible. Define down explicitly.')
        end
      end
    end

    class CommandRecorder
      def initialize
        @operations = []
      end

      def record(operation)
        @operations << operation
      end

      def replay_inverse(migration)
        @operations.reverse_each do |operation|
          operation.inverse.execute(migration)
        end
      end
    end

    class IndexStateFetcher
      def initialize(execute_query:)
        @execute_query = execute_query
      end

      def states(bucket, index_names)
        result = @execute_query.call(build_states_query(bucket, index_names))

        result.rows.to_a.each_with_object({}) do |row, states|
          name = row['name'] || row[:name]
          state = row['state'] || row[:state]
          states[name.to_s] = state.to_s.downcase
        end
      end

      def online?(bucket, index_names)
        states_by_name = states(bucket, index_names)
        Array(index_names).map(&:to_s).all? { |name| states_by_name[name] == 'online' }
      end

      private

      def build_states_query(bucket, index_names)
        names = Array(index_names).map { |name| quote(name.to_s) }.join(', ')
        <<~SQL.strip
          SELECT name, state
          FROM system:indexes
          WHERE keyspace_id = #{quote(bucket.to_s)}
            AND name IN [#{names}]
        SQL
      end

      def quote(value)
        "'#{value.gsub("'", "''")}'"
      end
    end

    class QueryBuilder
      def initialize(config: CouchbaseOrm.config.index)
        @config = config
      end

      def add_index(name, keys:, where: nil, num_replica: nil, defer_build: false)
        bucket = @config.effective_bucket
        raise ArgumentError.new('Missing index bucket configuration') if bucket.to_s.strip.empty?
        raise ArgumentError.new('Missing index keys configuration') if Array(keys).empty?

        query = +"CREATE INDEX `#{name}`\n"
        query << "ON `#{bucket}`(#{Array(keys).map { |key| "`#{key}`" }.join(',')})"
        query << "\nWHERE (#{where})" if where
        options = with_options(defer_build: defer_build, num_replica: num_replica)
        query << "\nWITH #{JSON.pretty_generate(options)}" unless options.empty?
        query
      end

      def build_indexes(index_names)
        bucket = @config.effective_bucket
        raise ArgumentError.new('Missing index bucket configuration') if bucket.to_s.strip.empty?

        names = Array(index_names)
        raise ArgumentError.new('At least one index name is required') if names.empty?

        index_lines = names.map { |name| "  `#{name}`" }.join(",\n")
        "BUILD INDEX ON `#{bucket}`\n(\n#{index_lines}\n);"
      end

      def remove_index(name)
        bucket = @config.effective_bucket
        raise ArgumentError.new('Missing index bucket configuration') if bucket.to_s.strip.empty?

        "DROP INDEX `#{bucket}`.`#{name}`"
      end

      private

      def with_options(defer_build:, num_replica:)
        options = {}
        options['defer_build'] = true if defer_build
        effective_num_replica = num_replica.nil? ? @config.num_replica : num_replica
        options['num_replica'] = effective_num_replica unless effective_num_replica.nil?
        options
      end
    end

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
      execute_operation(Operations::AddIndex.new(name, keys: keys, where: where, num_replica: num_replica, defer_build: defer_build))
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

    def execute_add_index(name, keys:, where: nil, num_replica: nil, defer_build: false)
      execute_query(query_builder.add_index(name, keys: keys, where: where, num_replica: num_replica, defer_build: defer_build))
    end

    def execute_remove_index(name)
      execute_query(query_builder.remove_index(name))
    end

    def execute_build_indexes(index_names, wait: false)
      execute_query(query_builder.build_indexes(index_names))
      wait_for_indexes_online(index_names) if wait
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

    def execute_query(query)
      CouchbaseOrm::Connection.cluster.query(query, Couchbase::Options::Query.new)
    end

    def wait_for_indexes_online(index_names)
      names = Array(index_names).map(&:to_s)

      loop do
        return if index_state_fetcher.online?(index_bucket, names)

        sleep(index_build_wait_interval_seconds)
      end
    end

    def query_builder
      @query_builder ||= QueryBuilder.new
    end

    def index_state_fetcher
      @index_state_fetcher ||= IndexStateFetcher.new(execute_query: method(:execute_query))
    end

    def index_bucket
      bucket = CouchbaseOrm.config.index.effective_bucket
      raise ArgumentError.new('Missing index bucket configuration') if bucket.to_s.strip.empty?

      bucket
    end

    def index_build_wait_interval_seconds
      1
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
