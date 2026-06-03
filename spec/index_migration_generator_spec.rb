# frozen_string_literal: true

require File.expand_path('support', __dir__)
require 'tmpdir'

describe CouchbaseOrm::IndexMigrationGenerator do
  it 'creates a timestamped migration file with a change template' do
    Dir.mktmpdir do |dir|
      now = Time.utc(2026, 8, 3, 10, 45, 0)
      generator = described_class.new(path: dir, now: now)

      file_path = generator.generate('AddWorkflowIndex')

      expect(File.basename(file_path)).to eq('20260803104500_add_workflow_index.rb')
      expect(File.read(file_path)).to eq(<<~RUBY)
        class AddWorkflowIndex < CouchbaseOrm::IndexMigration
          def change
          end
        end
      RUBY
    end
  end
end
