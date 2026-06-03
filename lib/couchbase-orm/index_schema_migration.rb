# frozen_string_literal: true

module CouchbaseOrm
  class IndexSchemaMigration
    DOCUMENT_ID = 'couchbaseorm::index_schema_migrations'

    def versions
      Array(current_document['versions']).map(&:to_s).sort
    end

    def add_version(version)
      updated_versions = (versions + [version.to_s]).uniq.sort
      persist_versions(updated_versions)
      updated_versions
    end

    def remove_version(version)
      updated_versions = versions - [version.to_s]
      persist_versions(updated_versions)
      updated_versions
    end

    private

    def collection
      CouchbaseOrm::Connection.bucket.default_collection
    end

    def current_document
      collection.get(DOCUMENT_ID).content
    rescue Couchbase::Error::DocumentNotFound
      { 'versions' => [] }
    end

    def persist_versions(new_versions)
      collection.upsert(DOCUMENT_ID, { 'versions' => new_versions })
    end
  end
end
