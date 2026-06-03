# frozen_string_literal: true

module CouchbaseOrm
  class Configuration
    class Index
      attr_accessor :bucket, :num_replica, :migrations_path

      def initialize
        @bucket = nil
        @num_replica = 0
        @migrations_path = 'db/indexes'
      end

      def effective_bucket
        bucket || CouchbaseOrm::Connection.config[:bucket]
      end
    end

    attr_reader :index

    def initialize
      @index = Index.new
    end
  end
end
