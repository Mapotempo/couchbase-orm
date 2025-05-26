require 'couchbase-orm'

def drop_index(bucket_name, index_name)
  CouchbaseOrm::Connection.cluster.query_indexes.drop_index(bucket_name, index_name)
rescue Couchbase::Error::IndexNotFound
  puts "Index #{index_name} not found, skipping drop."
end

def create_partial_index(index_name:, bucket_name:, fields:, where:, defer_build: true)
  fields_array = Array(fields)
  field_list = fields_array.map { |f| "`#{f}`" }.join(', ')
  defer_clause = defer_build ? 'WITH {"defer_build": true}' : ''

  drop_index(bucket_name, index_name)

  CouchbaseOrm::Connection.cluster.query(<<~N1QL)
    CREATE INDEX `#{index_name}`
    ON `#{bucket_name}`(#{field_list})
    WHERE #{where}
    #{defer_clause}
  N1QL
end

def build_and_watch_deferred_indexes(bucket:, timeout: 60)
  cluster = CouchbaseOrm::Connection.cluster

  # Récupère tous les index du bucket
  all_indexes = cluster.query_indexes.get_all_indexes(bucket)

  # Filtre les index différés (non ONLINE)
  index_names = all_indexes
                .reject { |idx| idx.state.casecmp('online').zero? || idx.name == '#primary' }
                .map(&:name)

  return unless index_names.any?

    # Build tous les indexes différés
  cluster.query_indexes.build_deferred_indexes(bucket)

    # Watch jusqu'à ce qu'ils soient en ligne
  options = Couchbase::Management::Options::Query::WatchIndexes.new
  cluster.query_indexes.watch_indexes(bucket, index_names, timeout, options)
end

def create_indexes
  create_partial_index(
    index_name: 'default_person_preference_ids_1',
    bucket_name: 'default',
    fields: 'preference_ids',
    where: "type = 'person'"
  )

  create_partial_index(
    index_name: 'default_post_person_id_1',
    bucket_name: 'default',
    fields: 'person_id',
    where: "type = 'post'"
  )

  create_partial_index(
    index_name: 'default_game_person_id_1',
    bucket_name: 'default',
    fields: 'person_id',
    where: "type = 'game'"
  )

  create_partial_index(
    index_name: 'default_preference_person_ids_1',
    bucket_name: 'default',
    fields: 'person_ids',
    where: "type = 'preference'"
  )

  build_and_watch_deferred_indexes(bucket: 'default')
end
