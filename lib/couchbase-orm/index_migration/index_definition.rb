# frozen_string_literal: true

module CouchbaseOrm
  class IndexMigration
    class IndexDefinition
      attr_reader :name, :keys, :where

      def initialize(name:, keys:, where: nil)
        @name = name.to_s
        @keys = normalize_keys(keys)
        @where = normalize_where(where)
      end

      def self.from_introspected(index_data)
        new(
          name: index_data.fetch(:name),
          keys: index_data.fetch(:index_key, []),
          where: index_data[:condition]
        )
      end

      def <=>(other)
        name <=> other.name
      end

      private

      def normalize_keys(raw_keys)
        Array(raw_keys).map { |key| normalize_key(key) }
      end

      def normalize_key(key)
        value = key.to_s.strip
        match = value.match(/\A`?([a-zA-Z_][a-zA-Z0-9_]*)`?\z/)
        return match[1].to_sym if match

        value
      end

      def normalize_where(where)
        stripped = where.to_s.strip
        stripped.empty? ? nil : stripped
      end
    end
  end
end
