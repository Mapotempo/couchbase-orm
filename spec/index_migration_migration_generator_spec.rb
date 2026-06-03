# frozen_string_literal: true

require File.expand_path('support', __dir__)
require 'tmpdir'

describe CouchbaseOrm::IndexMigration::MigrationGenerator do
  let(:date_on_type) do
    CouchbaseOrm::IndexMigration::IndexDefinition.new(
      name: 'date_on_type',
      keys: [:date],
      where: 'type is valued and date is valued'
    )
  end

  let(:type_company) do
    CouchbaseOrm::IndexMigration::IndexDefinition.new(
      name: 'type_company',
      keys: %i[type company_id],
      where: 'type is valued and company_id is valued'
    )
  end

  it 'renders deterministic source with deferred add_index, single build_indexes and reverse down' do
    generator = described_class.new

    source = generator.source_for([type_company, date_on_type])

    expect(source).to include('class InitialIndexes < CouchbaseOrm::IndexMigration')
    expect(source).to include("add_index(\n      :date_on_type,")
    expect(source).to include('keys: [:date],')
    expect(source).to include('defer_build: true')
    expect(source).to include("build_indexes(\n      :date_on_type,\n      :type_company\n    )")
    expect(source).to include("def down\n    remove_index :type_company\n    remove_index :date_on_type\n  end")
  end

  it 'creates timestamped file with custom migration class name' do
    Dir.mktmpdir do |dir|
      now = Time.utc(2026, 8, 10, 12, 0, 0)
      generator = described_class.new(path: dir, now: now)

      file_path = generator.generate([type_company], name: 'FleetIndexes')

      expect(File.basename(file_path)).to eq('20260810120000_fleet_indexes.rb')
      expect(File.read(file_path)).to include('class FleetIndexes < CouchbaseOrm::IndexMigration')
    end
  end

  it 'produces the same source content for the same index set regardless of input order' do
    generator = described_class.new

    first_source = generator.source_for([date_on_type, type_company])
    second_source = generator.source_for([type_company, date_on_type])

    expect(first_source).to eq(second_source)
  end
end
