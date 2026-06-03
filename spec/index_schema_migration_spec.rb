# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe CouchbaseOrm::IndexSchemaMigration do
  let(:collection) { instance_double(Couchbase::Collection) }
  let(:bucket) { instance_double(Couchbase::Bucket, default_collection: collection) }

  before do
    allow(CouchbaseOrm::Connection).to receive(:bucket).and_return(bucket)
  end

  it 'returns sorted versions' do
    response = instance_double(Couchbase::Collection::GetResult, content: { 'versions' => %w[20250808120000 20250808110000] })
    allow(collection).to receive(:get).with(described_class::DOCUMENT_ID).and_return(response)

    expect(described_class.new.versions).to eq(%w[20250808110000 20250808120000])
  end

  it 'adds a version and persists deduplicated values' do
    response = instance_double(Couchbase::Collection::GetResult, content: { 'versions' => ['20250808110000'] })
    allow(collection).to receive(:get).with(described_class::DOCUMENT_ID).and_return(response)

    expect(collection).to receive(:upsert).with(
      described_class::DOCUMENT_ID,
      { 'versions' => %w[20250808110000 20250808120000] }
    )

    described_class.new.add_version('20250808120000')
  end

  it 'removes a version and persists values' do
    response = instance_double(Couchbase::Collection::GetResult, content: { 'versions' => %w[20250808110000 20250808120000] })
    allow(collection).to receive(:get).with(described_class::DOCUMENT_ID).and_return(response)

    expect(collection).to receive(:upsert).with(
      described_class::DOCUMENT_ID,
      { 'versions' => ['20250808110000'] }
    )

    described_class.new.remove_version('20250808120000')
  end
end
