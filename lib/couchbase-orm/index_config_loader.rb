# frozen_string_literal: true

require 'active_support/core_ext/hash/indifferent_access'

module CouchbaseOrm
  class IndexConfigLoader
    SUPPORTED_KEYS = %i[bucket migrations_path num_replica].freeze

    def self.apply(config_hash)
      config_hash = config_hash.with_indifferent_access
      index_hash = (config_hash[:index] || {}).with_indifferent_access

      index_config = {
        bucket: config_hash[:bucket]
      }.merge(index_hash.slice(*SUPPORTED_KEYS))

      index_config.each do |key, value|
        CouchbaseOrm.config.index.public_send("#{key}=", value)
      end
    end
  end
end
