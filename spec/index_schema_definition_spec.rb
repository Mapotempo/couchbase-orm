# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe CouchbaseOrm::IndexSchema do
  it 'tracks add_index, remove_index and rename_index in Hash<Symbol, IndexDefinition>' do
    indexes = described_class.define do
      add_index(:type_company, keys: %i[type company_id])
      add_index(:date_on_type, keys: [:date], where: 'type is valued', defer_build: true)
      remove_index(:type_company)
      rename_index(:date_on_type, :date_on_type_v2)
    end

    expect(indexes.keys).to eq([:date_on_type_v2])
    expect(indexes[:date_on_type_v2]).to be_a(CouchbaseOrm::IndexDefinition)
    expect(indexes[:date_on_type_v2].keys).to eq([:date])
    expect(indexes[:date_on_type_v2].where).to eq('type is valued')
    expect(indexes[:date_on_type_v2].defer_build).to be(true)
  end

  it 'supports renaming and removing non-conventional names' do
    indexes = described_class.define do
      add_index('date-on-type', keys: [:date])
      rename_index('date-on-type', 'date-on-type-v2')
      remove_index('date-on-type-v2')
      add_index('date-on-type-v3', keys: [:date])
    end

    expect(indexes.keys).to eq(['date-on-type-v3'])
    expect(indexes['date-on-type-v3']).to be_a(CouchbaseOrm::IndexDefinition)
  end
end
