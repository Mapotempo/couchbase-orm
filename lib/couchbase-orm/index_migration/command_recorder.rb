# frozen_string_literal: true

module CouchbaseOrm
  class IndexMigration
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
  end
end
