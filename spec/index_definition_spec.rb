# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe CouchbaseOrm::IndexMigration::IndexDefinition do
  it 'normalizes simple keys to symbols and strips where clause' do
    definition = described_class.from_introspected(
      name: 'type_company',
      index_key: ['`type`', 'company_id'],
      condition: '  type is valued  '
    )

    expect(definition.name).to eq('type_company')
    expect(definition.keys).to eq(%i[type company_id])
    expect(definition.where).to eq('type is valued')
  end

  it 'keeps expression keys as strings' do
    definition = described_class.new(name: 'by_lower_name', keys: ['LOWER(`name`)'])

    expect(definition.keys).to eq(['LOWER(`name`)'])
  end
end
