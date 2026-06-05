# frozen_string_literal: true

require 'json'

module CouchbaseOrm
  class IndexMigration
    class QueryBuilder
      def initialize(config: CouchbaseOrm.config.index)
        @config = config
      end

      def create_index(index_definition)
        bucket = @config.effective_bucket
        raise ArgumentError.new('Missing index bucket configuration') if bucket.to_s.strip.empty?
        raise ArgumentError.new('Missing index keys configuration') if Array(index_definition.keys).empty?

        query = +"CREATE INDEX `#{index_definition.name}`\n"
        query << "ON `#{bucket}`(#{Array(index_definition.keys).map { |key| format_key(key) }.join(',')})"
        query << "\nWHERE (#{index_definition.where})" if index_definition.where
        options = with_options(defer_build: index_definition.defer_build, num_replica: index_definition.num_replica)
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

      def states_query(bucket, index_names)
        names = Array(index_names).map { |name| quote(name.to_s) }.join(', ')
        <<~SQL.strip
          SELECT name, state
          FROM system:indexes
          WHERE keyspace_id = #{quote(bucket.to_s)}
            AND name IN [#{names}]
        SQL
      end

      private

      def format_key(key)
        key.is_a?(Symbol) ? "`#{key}`" : key.to_s
      end

      def with_options(defer_build:, num_replica:)
        options = {}
        options['defer_build'] = true if defer_build
        effective_num_replica = num_replica.nil? ? @config.num_replica : num_replica
        options['num_replica'] = effective_num_replica unless effective_num_replica.nil?
        options
      end

      def quote(value)
        "'#{value.gsub("'", "''")}'"
      end
    end
  end
end
