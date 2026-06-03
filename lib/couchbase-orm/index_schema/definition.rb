# frozen_string_literal: true

module CouchbaseOrm
  class IndexSchema
    class Definition
      attr_reader :indexes

      def initialize
        @indexes = {}
      end

      def add_index(name, keys:, where: nil, num_replica: nil, defer_build: false)
        index_name = normalize_name(name)
        definition = {
          keys: normalize_keys(keys)
        }

        normalized_where = normalize_where(where)
        definition[:where] = normalized_where if normalized_where
        definition[:num_replica] = num_replica unless num_replica.nil?
        definition[:defer_build] = true if defer_build

        @indexes[index_name] = definition
      end

      def remove_index(name)
        @indexes.delete(normalize_name(name))
      end

      def rename_index(old_name, new_name)
        old_index_name = normalize_name(old_name)
        new_index_name = normalize_name(new_name)

        definition = @indexes.delete(old_index_name)
        return unless definition

        @indexes[new_index_name] = definition
      end

      private

      def normalize_name(name)
        name.to_sym
      end

      def normalize_keys(raw_keys)
        Array(raw_keys).map { |key| normalize_key(key) }
      end

      def normalize_key(key)
        return key if key.is_a?(Symbol)

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
