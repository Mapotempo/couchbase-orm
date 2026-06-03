# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe CouchbaseOrm::IndexMigrator do
  let(:context) { instance_double(CouchbaseOrm::IndexMigrationContext) }
  let(:schema_migration) { instance_double(CouchbaseOrm::IndexSchemaMigration) }
  let(:out) { StringIO.new }

  context 'when applying and rolling back migrations' do
    let(:migration_class) { Class.new { def migrate(_direction); end } }
    let(:migration_def) do
      CouchbaseOrm::IndexMigrationContext::Migration.new(
        version: '20250808120000',
        name: 'AddWorkflowIndex',
        klass: migration_class,
        path: 'db/indexes/20250808120000_add_workflow_index.rb'
      )
    end

    it 'migrates pending versions and stores them' do
      migration_instance = instance_double(migration_class)
      allow(migration_class).to receive(:new).and_return(migration_instance)
      allow(schema_migration).to receive(:versions).and_return([])
      allow(context).to receive(:pending_migrations).with([]).and_return([migration_def])
      expect(migration_instance).to receive(:migrate).with(:up)
      expect(schema_migration).to receive(:add_version).with('20250808120000')

      described_class.new(context: context, schema_migration: schema_migration, out: out).migrate
    end

    it 'rolls back latest version and removes it from state' do
      migration_instance = instance_double(migration_class)
      allow(migration_class).to receive(:new).and_return(migration_instance)
      allow(schema_migration).to receive(:versions).and_return(%w[20250808110000 20250808120000])
      allow(context).to receive(:find).with('20250808120000').and_return(migration_def)
      expect(migration_instance).to receive(:migrate).with(:down)
      expect(schema_migration).to receive(:remove_version).with('20250808120000')

      described_class.new(context: context, schema_migration: schema_migration, out: out).rollback
    end
  end

  it 'returns formatted status lines' do
    migration_class = Class.new { def migrate(_direction); end }
    migration_one = CouchbaseOrm::IndexMigrationContext::Migration.new(
      version: '20250808110000', name: 'InitialIndexes',
      klass: migration_class, path: 'db/indexes/20250808110000_initial_indexes.rb'
    )
    migration_two = CouchbaseOrm::IndexMigrationContext::Migration.new(
      version: '20250808120000', name: 'AddWorkflowIndex',
      klass: migration_class, path: 'db/indexes/20250808120000_add_workflow_index.rb'
    )
    allow(schema_migration).to receive(:versions).and_return(['20250808110000'])
    allow(context).to receive(:migrations).and_return([migration_one, migration_two])

    lines = described_class.new(context: context, schema_migration: schema_migration, out: out).status

    expect(lines).to eq([
      'up     20250808110000 InitialIndexes',
      'down   20250808120000 AddWorkflowIndex'
    ])
    expect(out.string).to include('up     20250808110000 InitialIndexes')
    expect(out.string).to include('down   20250808120000 AddWorkflowIndex')
  end
end
