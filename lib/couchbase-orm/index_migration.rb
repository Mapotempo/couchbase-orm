# frozen_string_literal: true

require 'json'
require 'couchbase'

module CouchbaseOrm
  class IndexMigration
    class IrreversibleMigration < StandardError; end

    module Operations
      class AddIndex
        attr_reader :name, :keys, :where

        def initialize(name, keys:, where: nil)
          @name = name
          @keys = keys
          @where = where
        end

        def execute(migration)
          migration.execute_add_index(name, keys: keys, where: where)
        end

        def inverse
          RemoveIndex.new(name)
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
          raise IrreversibleMigration, 'remove_index is not reversible. Define down explicitly.'
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

    class QueryBuilder
      def initialize(config: CouchbaseOrm.config.index)
        @config = config
      end

      def add_index(name, keys:, where: nil)
        bucket = @config.effective_bucket
        raise ArgumentError, 'Missing index bucket configuration' if bucket.to_s.strip.empty?
        raise ArgumentError, 'Missing index keys configuration' if Array(keys).empty?

        query = +"CREATE INDEX `#{name}`\n"
        query << "ON `#{bucket}`(#{Array(keys).map { |key| "`#{key}`" }.join(',')})"
        query << "\nWHERE (#{where})" if where
        query << "\nWITH #{JSON.pretty_generate(with_options)}"
        query
      end

      def remove_index(name)
        bucket = @config.effective_bucket
        raise ArgumentError, 'Missing index bucket configuration' if bucket.to_s.strip.empty?

        "DROP INDEX `#{bucket}`.`#{name}`"
      end

      private

      def with_options
        {
          'defer_build' => @config.defer_build,
          'num_replica' => @config.num_replica
        }
      end
    end

    def migrate(direction)
      direction = direction.to_sym
      raise ArgumentError, 'direction must be :up or :down' unless %i[up down].include?(direction)

      if direction == :up
        run_up
      else
        run_down
      end
    end

    def add_index(name, keys:, where: nil)
      execute_operation(Operations::AddIndex.new(name, keys: keys, where: where))
    end

    def remove_index(name)
      execute_operation(Operations::RemoveIndex.new(name))
    end

    def execute_add_index(name, keys:, where: nil)
      execute_query(query_builder.add_index(name, keys: keys, where: where))
    end

    def execute_remove_index(name)
      execute_query(query_builder.remove_index(name))
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

    def query_builder
      @query_builder ||= QueryBuilder.new
    end

    def method_overridden?(method_name)
      self.class.instance_method(method_name).owner != CouchbaseOrm::IndexMigration
    end

    def change
      raise NotImplementedError, 'Define change or up/down in your migration'
    end

    def up
      change
    end

    def down
      raise NotImplementedError, 'Define down for non-reversible migrations'
    end
  end
end