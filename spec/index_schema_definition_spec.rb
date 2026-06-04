# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe CouchbaseOrm::IndexSchema::Definition do
  it 'tracks add_index, remove_index and rename_index operations' do
    definition = described_class.new

    definition.add_index(:type_company, keys: %i[type company_id])
    definition.add_index(:date_on_type, keys: [:date], where: 'type is valued', defer_build: true)

    expect(definition.indexes).to eq(
      type_company: {
        keys: %i[type company_id]
      },
      date_on_type: {
        keys: [:date],
        where: 'type is valued',
        defer_build: true
      }
    )

    definition.remove_index(:type_company)
    definition.rename_index(:date_on_type, :date_on_type_v2)

    expect(definition.indexes).to eq(
      date_on_type_v2: {
        keys: [:date],
        where: 'type is valued',
        defer_build: true
      }
    )
  end
end
