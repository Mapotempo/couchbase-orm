# frozen_string_literal: true

module CouchbaseOrm
  class Configuration
    class Index
      attr_accessor :bucket, :num_replica, :defer_build, :migrations_path

      def initialize
        @bucket = nil
        @num_replica = 0
        @defer_build = true
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
