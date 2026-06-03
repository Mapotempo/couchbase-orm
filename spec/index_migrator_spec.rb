# frozen_string_literal: true

require File.expand_path('support', __dir__)
require 'tmpdir'

describe CouchbaseOrm::IndexMigrationContext do
  it 'loads and sorts migrations from disk' do
    Dir.mktmpdir do |dir|
      File.write(
        File.join(dir, '20250808120000_add_workflow_index.rb'),
        "class AddWorkflowIndex < CouchbaseOrm::IndexMigration\nend\n"
      )
      File.write(
        File.join(dir, '20250808110000_initial_indexes.rb'),
        "class InitialIndexes < CouchbaseOrm::IndexMigration\nend\n"
      )

      context = described_class.new(path: dir)
      versions = context.migrations.map(&:version)
      names = context.migrations.map(&:name)

      expect(versions).to eq(%w[20250808110000 20250808120000])
      expect(names).to eq(%w[InitialIndexes AddWorkflowIndex])
    end
  end
end

describe CouchbaseOrm::IndexMigrator do
  let(:context) { instance_double(CouchbaseOrm::IndexMigrationContext) }
  let(:schema_migration) { instance_double(CouchbaseOrm::IndexSchemaMigration) }
  let(:out) { StringIO.new }

  let(:migration_one_class) do
    Class.new do
      def migrate(_direction); end
    end
  end

  let(:migration_two_class) do
    Class.new do
      def migrate(_direction); end
    end
  end

  let(:migration_one) do
    CouchbaseOrm::IndexMigrationContext::Migration.new(
      version: '20250808110000',
      name: 'InitialIndexes',
      klass: migration_one_class,
      path: 'db/indexes/20250808110000_initial_indexes.rb'
    )
  end

  let(:migration_two) do
    CouchbaseOrm::IndexMigrationContext::Migration.new(
      version: '20250808120000',
      name: 'AddWorkflowIndex',
      klass: migration_two_class,
      path: 'db/indexes/20250808120000_add_workflow_index.rb'
    )
  end

  it 'migrates pending versions and stores them' do
    expect(context).to receive(:pending_migrations).with(['20250808110000']).and_return([migration_two])
    expect(schema_migration).to receive(:versions).and_return(['20250808110000'])
    expect_any_instance_of(migration_two_class).to receive(:migrate).with(:up)
    expect(schema_migration).to receive(:add_version).with('20250808120000')

    described_class.new(context: context, schema_migration: schema_migration, out: out).migrate
  end

  it 'rolls back latest version and removes it from state' do
    expect(schema_migration).to receive(:versions).and_return(%w[20250808110000 20250808120000])
    expect(context).to receive(:find).with('20250808120000').and_return(migration_two)
    expect_any_instance_of(migration_two_class).to receive(:migrate).with(:down)
    expect(schema_migration).to receive(:remove_version).with('20250808120000')

    described_class.new(context: context, schema_migration: schema_migration, out: out).rollback
  end

  it 'returns formatted status lines' do
    expect(schema_migration).to receive(:versions).and_return(['20250808110000'])
    expect(context).to receive(:migrations).and_return([migration_one, migration_two])

    lines = described_class.new(context: context, schema_migration: schema_migration, out: out).status

    expect(lines).to eq([
      'up     20250808110000 InitialIndexes',
      'down   20250808120000 AddWorkflowIndex'
    ])
    expect(out.string).to include('up     20250808110000 InitialIndexes')
    expect(out.string).to include('down   20250808120000 AddWorkflowIndex')
  end
end