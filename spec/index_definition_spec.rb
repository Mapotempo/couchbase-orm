# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe CouchbaseOrm::IndexDefinition do
  it 'normalizes simple keys to symbols and strips where clause' do
    definition = described_class.from_introspected(
      name: 'type_company',
      index_key: ['`type`', 'company_id'],
      condition: '  type is valued  '
    )

    expect(definition.name).to eq(:type_company)
    expect(definition.keys).to eq(%i[type company_id])
    expect(definition.where).to eq('type is valued')
  end

  it 'keeps expression keys as strings' do
    definition = described_class.new(name: 'by_lower_name', keys: ['LOWER(`name`)'])

    expect(definition.keys).to eq(['LOWER(`name`)'])
  end

  it 'keeps non-conventional names as strings' do
    definition = described_class.new(name: 'type-company', keys: [:type])

    expect(definition.name).to eq('type-company')
  end

  it 'tracks defer_build and num_replica attributes' do
    definition = described_class.new(
      name: :type_company,
      keys: %i[type company_id],
      defer_build: true,
      num_replica: 1
    )

    expect(definition.defer_build).to be(true)
    expect(definition.num_replica).to eq(1)
  end
end
