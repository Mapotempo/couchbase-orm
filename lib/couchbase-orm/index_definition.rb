# frozen_string_literal: true

module CouchbaseOrm
  class IndexDefinition
    attr_reader :name, :keys, :where, :defer_build, :num_replica

    NAME_SYMBOL_PATTERN = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/

    def initialize(name:, keys:, where: nil, defer_build: false, num_replica: nil)
      @name = normalize_name(name)
      @keys = normalize_keys(keys)
      @where = normalize_where(where)
      @defer_build = !!defer_build
      @num_replica = num_replica
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

    def normalize_name(name)
      self.class.normalize_name(name)
    end

    class << self
      def normalize_name(name)
        return name if name.is_a?(Symbol)

        value = name.to_s.strip
        return value.to_sym if value.match?(NAME_SYMBOL_PATTERN)

        value
      end
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
