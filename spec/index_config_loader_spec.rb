# frozen_string_literal: true

require File.expand_path('support', __dir__)
require 'couchbase-orm/index_config_loader'

describe CouchbaseOrm::IndexConfigLoader do
  before do
    CouchbaseOrm.reset_config!
  end

  it 'loads migrations_path from nested index config' do
    described_class.apply(
      bucket: 'fleet-dev',
      index: {
        migrations_path: 'custom/indexes'
      }
    )

    expect(CouchbaseOrm.config.index.migrations_path).to eq('custom/indexes')
  end

  it 'loads num_replica from nested index config' do
    described_class.apply(
      bucket: 'fleet-dev',
      index: {
        num_replica: 1
      }
    )

    expect(CouchbaseOrm.config.index.num_replica).to eq(1)
  end

  it 'loads schema_path from nested index config' do
    described_class.apply(
      bucket: 'fleet-dev',
      index: {
        schema_path: 'custom/index_schema.rb'
      }
    )

    expect(CouchbaseOrm.config.index.schema_path).to eq('custom/index_schema.rb')
  end

  it 'defaults index bucket to connection bucket from top-level config' do
    described_class.apply(bucket: 'fleet-dev')

    expect(CouchbaseOrm.config.index.bucket).to eq('fleet-dev')
  end

  it 'allows explicit index bucket override' do
    described_class.apply(
      bucket: 'fleet-dev',
      index: {
        bucket: 'fleet-indexes'
      }
    )

    expect(CouchbaseOrm.config.index.bucket).to eq('fleet-indexes')
  end

  it 'preserves index defaults when values are absent' do
    described_class.apply(bucket: 'fleet-dev')

    expect(CouchbaseOrm.config.index.migrations_path).to eq('db/indexes')
    expect(CouchbaseOrm.config.index.schema_path).to eq('db/index_schema.rb')
    expect(CouchbaseOrm.config.index.num_replica).to eq(0)
  end

  it 'ignores unknown keys under index' do
    expect do
      described_class.apply(
        bucket: 'fleet-dev',
        index: {
          foo: 'bar'
        }
      )
    end.not_to raise_error

    expect(CouchbaseOrm.config.index.respond_to?(:foo)).to be(false)
  end

  it 'supports runtime override after loading yaml values' do
    described_class.apply(
      bucket: 'fleet-dev',
      index: {
        num_replica: 1
      }
    )

    CouchbaseOrm.configure do |config|
      config.index.num_replica = 2
    end

    expect(CouchbaseOrm.config.index.num_replica).to eq(2)
  end
end
