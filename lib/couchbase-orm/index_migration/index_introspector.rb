# frozen_string_literal: true

module CouchbaseOrm
  class IndexMigration
    class IndexIntrospector
      def initialize(execute_query: nil)
        @execute_query = execute_query || method(:default_execute_query)
      end

      def indexes(bucket: configured_bucket)
        bucket_name = bucket.to_s
        raise ArgumentError.new('Missing index bucket configuration') if bucket_name.strip.empty?

        result = @execute_query.call(query_for(bucket_name))
        rows = result.respond_to?(:rows) ? result.rows : []

        Array(rows).map { |row| normalize_row(row) }
                   .select { |row| row[:keyspace_id] == bucket_name }
                   .reject { |row| row[:is_primary] }
                   .sort_by { |row| row[:name] }
                   .map { |row| row.slice(:name, :index_key, :condition, :state) }
      end

      private

      def configured_bucket
        CouchbaseOrm.config.index.effective_bucket
      end

      def query_for(bucket_name)
        <<~SQL.strip
          SELECT *
          FROM system:indexes
          WHERE keyspace_id = #{quote(bucket_name)}
        SQL
      end

      def quote(value)
        "'#{value.gsub("'", "''")}'"
      end

      def normalize_row(row)
        data = row.respond_to?(:transform_keys) ? row : row.to_h
        index_data = data['indexes'] || data[:indexes] || data

        {
          name: fetch(index_data, :name).to_s,
          index_key: Array(fetch(index_data, :index_key)),
          condition: normalize_condition(fetch(index_data, :condition)),
          state: fetch(index_data, :state).to_s,
          is_primary: fetch(index_data, :is_primary),
          keyspace_id: fetch(index_data, :keyspace_id).to_s
        }
      end

      def fetch(hash, key)
        hash[key] || hash[key.to_s]
      end

      def normalize_condition(value)
        stripped = value.to_s.strip
        stripped.empty? ? nil : stripped
      end

      def default_execute_query(query)
        CouchbaseOrm::Connection.cluster.query(query, Couchbase::Options::Query.new)
      end
    end
  end
end
