# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe CouchbaseOrm::IndexMigration::IndexIntrospector do
  it 'filters by bucket, ignores primary indexes and sorts by name' do
    query_result = instance_double(Couchbase::Cluster::QueryResult, rows: introspected_rows)
    execute_query = build_execute_query(query_result)

    indexes = described_class.new(execute_query: execute_query).indexes(bucket: 'fleet')

    expect(indexes).to eq(expected_indexes)
  end

  it 'raises when bucket is missing' do
    expect do
      described_class.new(execute_query: ->(_query) { raise 'not called' }).indexes(bucket: nil)
    end.to raise_error(ArgumentError, /Missing index bucket configuration/)
  end

  def build_execute_query(query_result)
    lambda do |query|
      expect(query).to include('FROM system:indexes')
      expect(query).to include("WHERE keyspace_id = 'fleet'")
      query_result
    end
  end

  def introspected_rows
    [
      {
        'indexes' => {
          'name' => 'type_company',
          'index_key' => ['`type`', '`company_id`'],
          'condition' => 'type is valued',
          'state' => 'online',
          'is_primary' => false,
          'keyspace_id' => 'fleet'
        }
      },
      {
        'indexes' => {
          'name' => 'date_on_type',
          'index_key' => ['`date`'],
          'condition' => 'type is valued and date is valued',
          'state' => 'online',
          'is_primary' => false,
          'keyspace_id' => 'fleet'
        }
      },
      {
        'indexes' => {
          'name' => '#primary',
          'index_key' => [],
          'state' => 'online',
          'is_primary' => true,
          'keyspace_id' => 'fleet'
        }
      },
      {
        'indexes' => {
          'name' => 'other_bucket_index',
          'index_key' => ['`type`'],
          'state' => 'online',
          'is_primary' => false,
          'keyspace_id' => 'other'
        }
      }
    ]
  end

  def expected_indexes
    [
      {
        name: 'date_on_type',
        index_key: ['`date`'],
        condition: 'type is valued and date is valued',
        state: 'online'
      },
      {
        name: 'type_company',
        index_key: ['`type`', '`company_id`'],
        condition: 'type is valued',
        state: 'online'
      }
    ]
  end
end
