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

      expect(context.migrations.map(&:version)).to eq(%w[20250808110000 20250808120000])
      expect(context.migrations.map(&:name)).to eq(%w[InitialIndexes AddWorkflowIndex])
    end
  end
end
