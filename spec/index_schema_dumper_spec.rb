# frozen_string_literal: true

require File.expand_path('support', __dir__)
require 'tmpdir'

describe CouchbaseOrm::IndexSchema::Dumper do
  it 'replays migrations in memory and writes deterministic schema output' do
    Dir.mktmpdir do |dir|
      migrations_path = File.join(dir, 'indexes')
      schema_path = File.join(dir, 'index_schema.rb')
      write_migrations(migrations_path)

      context = CouchbaseOrm::IndexMigrationContext.new(path: migrations_path)
      dumper = described_class.new(context: context, path: schema_path)

      first_dump_path = dumper.dump
      first_dump = File.read(first_dump_path)

      second_dump_path = dumper.dump
      second_dump = File.read(second_dump_path)

      expect(first_dump).to eq(second_dump)
      expect(first_dump).to include('CouchbaseOrm::IndexSchema.define(version: 20260101120000) do')
      expect(first_dump).to include("add_index :date_on_type,\n    keys: [:date],\n    defer_build: true")
      expect(first_dump).to include("add_index :type_company,\n    keys: [:type, :company_id],\n    where: \"type is valued and company_id is valued\",\n    num_replica: 2")
      expect(first_dump).not_to include('remove_index')
    end
  end

  it 'dumps non-conventional names as valid ruby values' do
    indexes = {
      'type-company' => CouchbaseOrm::IndexDefinition.new(name: 'type-company', keys: [:type]),
      :date_on_type => CouchbaseOrm::IndexDefinition.new(name: :date_on_type, keys: [:date])
    }

    source = described_class.new.source_for(indexes, version: 20260101120000)

    expect(source).to include('add_index :date_on_type,')
    expect(source).to include('add_index "type-company",')
    expect { RubyVM::InstructionSequence.compile(source) }.not_to raise_error
  end

  def write_migrations(migrations_path)
    FileUtils.mkdir_p(migrations_path)

    File.write(
      File.join(migrations_path, '20260101110000_add_type_company_index.rb'),
      <<~RUBY
        class AddTypeCompanyIndex < CouchbaseOrm::IndexMigration
          def change
            add_index :type_company,
              keys: [:company_id, :type]
          end
        end
      RUBY
    )

    File.write(
      File.join(migrations_path, '20260101120000_replace_type_company_index.rb'),
      <<~RUBY
        class ReplaceTypeCompanyIndex < CouchbaseOrm::IndexMigration
          def up
            remove_index :type_company

            add_index :type_company,
              keys: [:type, :company_id],
              where: "type is valued and company_id is valued",
              num_replica: 2

            add_index :date_on_type,
              keys: [:date],
              defer_build: true
          end
        end
      RUBY
    )
  end
end
