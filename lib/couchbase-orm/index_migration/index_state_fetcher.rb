# frozen_string_literal: true

module CouchbaseOrm
  class IndexMigration
    class IndexStateFetcher
      def states(migration, bucket, index_names)
        result = migration.execute_query(migration.query_builder.states_query(bucket, index_names))

        result.rows.to_a.each_with_object({}) do |row, states|
          name = row['name'] || row[:name]
          state = row['state'] || row[:state]
          states[name.to_s] = state.to_s.downcase
        end
      end

      def online?(migration, bucket, index_names)
        states_by_name = states(migration, bucket, index_names)
        Array(index_names).map(&:to_s).all? { |name| states_by_name[name] == 'online' }
      end
    end
  end
end
