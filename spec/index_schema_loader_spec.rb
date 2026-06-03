# frozen_string_literal: true

require File.expand_path('support', __dir__)
require 'tmpdir'

describe CouchbaseOrm::IndexSchema::Loader do
  let(:schema_source) do
    <<~RUBY
      CouchbaseOrm::IndexSchema.define(version: 20260101120000) do
        add_index :type_company,
          keys: [:type],
          defer_build: true

        add_index :date_on_type,
          keys: [:date],
          defer_build: true
      end
    RUBY
  end

  before do
    CouchbaseOrm.reset_config!
    CouchbaseOrm.configure do |config|
      config.index.bucket = 'fleet-prod'
      config.index.num_replica = 0
    end
  end

  it 'loads schema file and creates indexes without replaying migrations' do
    Dir.mktmpdir do |dir|
      migrations_path = File.join(dir, 'indexes')
      schema_path = File.join(dir, 'index_schema.rb')
      FileUtils.mkdir_p(migrations_path)

      File.write(
        File.join(migrations_path, '20260101110000_should_not_be_loaded.rb'),
        "raise 'index migration files should not be loaded by index:schema:load'\n"
      )
      File.write(schema_path, schema_source)

      CouchbaseOrm.configure do |config|
        config.index.migrations_path = migrations_path
      end

      cluster = instance_double(Couchbase::Cluster)
      allow(CouchbaseOrm::Connection).to receive(:cluster).and_return(cluster)

      expect_schema_load_queries(cluster)

      version = described_class.new(path: schema_path).load

      expect(version).to eq(20260101120000)
    end
  end

  def expect_schema_load_queries(cluster)
    expect(cluster).to receive(:query).with(/CREATE INDEX `date_on_type`/, instance_of(Couchbase::Options::Query)).ordered
    expect(cluster).to receive(:query).with(/CREATE INDEX `type_company`/, instance_of(Couchbase::Options::Query)).ordered
    expect(cluster).to receive(:query).with(<<~SQL.strip, instance_of(Couchbase::Options::Query)).ordered
      BUILD INDEX ON `fleet-prod`
      (
        `date_on_type`,
        `type_company`
      );
    SQL
  end
end
