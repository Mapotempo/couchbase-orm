# frozen_string_literal: true

require File.expand_path('support', __dir__)

describe CouchbaseOrm::IndexMigration do
  before do
    CouchbaseOrm.reset_config!
    CouchbaseOrm.configure do |config|
      config.index.bucket = 'fleet-prod'
      config.index.num_replica = 1
    end
  end

  describe CouchbaseOrm::IndexMigration::QueryBuilder do
    it 'builds create index query without deferred build option by default' do
      query = described_class.new.add_index(
        :type_company,
        keys: %i[type company_id],
        where: 'type is valued and company_id is valued'
      )

      expect(query).to eq(<<~SQL.strip)
        CREATE INDEX `type_company`
        ON `fleet-prod`(`type`,`company_id`)
        WHERE (type is valued and company_id is valued)
        WITH {
          "num_replica": 1
        }
      SQL
    end

    it 'builds create index query with deferred build option' do
      query = described_class.new.add_index(
        :type_company,
        keys: %i[type company_id],
        where: 'type is valued and company_id is valued',
        defer_build: true
      )

      expect(query).to eq(<<~SQL.strip)
        CREATE INDEX `type_company`
        ON `fleet-prod`(`type`,`company_id`)
        WHERE (type is valued and company_id is valued)
        WITH {
          "defer_build": true,
          "num_replica": 1
        }
      SQL
    end

    it 'builds build indexes query' do
      query = described_class.new.build_indexes(%i[type_company date_on_type])

      expect(query).to eq(<<~SQL.strip)
        BUILD INDEX ON `fleet-prod`
        (
          `type_company`,
          `date_on_type`
        );
      SQL
    end

    it 'builds drop index query' do
      query = described_class.new.remove_index(:type_company)
      expect(query).to eq('DROP INDEX `fleet-prod`.`type_company`')
    end
  end

  it 'runs up and reverses change on down' do
    migration_class = Class.new(CouchbaseOrm::IndexMigration) do
      def change
        add_index :type_company, keys: %i[type company_id], where: 'type is valued and company_id is valued'
      end
    end

    cluster = instance_double(Couchbase::Cluster)
    allow(CouchbaseOrm::Connection).to receive(:cluster).and_return(cluster)

    expect(cluster).to receive(:query).with(/CREATE INDEX `type_company`/, instance_of(Couchbase::Options::Query))
    migration_class.new.migrate(:up)

    expect(cluster).to receive(:query).with('DROP INDEX `fleet-prod`.`type_company`', instance_of(Couchbase::Options::Query))
    migration_class.new.migrate(:down)
  end

  it 'raises irreversible migration when remove_index is used in change' do
    migration_class = Class.new(CouchbaseOrm::IndexMigration) do
      def change
        remove_index :legacy_index
      end
    end

    expect { migration_class.new.migrate(:down) }
      .to raise_error(CouchbaseOrm::IndexMigration::IrreversibleMigration)
  end

  it 'executes deferred indexes then explicit build in order' do
    migration_class = Class.new(CouchbaseOrm::IndexMigration) do
      def up
        add_index :type_company, keys: %i[type company_id], where: 'type is valued and company_id is valued', defer_build: true
        add_index :date_on_type, keys: [:date], where: 'type is valued and date is valued', defer_build: true
        build_indexes :type_company, :date_on_type
      end
    end

    cluster = instance_double(Couchbase::Cluster)
    allow(CouchbaseOrm::Connection).to receive(:cluster).and_return(cluster)

    expect(cluster).to receive(:query).with(/CREATE INDEX `type_company`[\s\S]*"defer_build": true/, instance_of(Couchbase::Options::Query)).ordered
    expect(cluster).to receive(:query).with(/CREATE INDEX `date_on_type`[\s\S]*"defer_build": true/, instance_of(Couchbase::Options::Query)).ordered
    expect(cluster).to receive(:query).with(<<~SQL.strip, instance_of(Couchbase::Options::Query)).ordered
      BUILD INDEX ON `fleet-prod`
      (
        `type_company`,
        `date_on_type`
      );
    SQL

    migration_class.new.migrate(:up)
  end

  it 'raises argument error when build_indexes receives no names' do
    migration_class = Class.new(described_class)

    expect { migration_class.new.build_indexes }
      .to raise_error(ArgumentError, /At least one index name is required/)
  end

  it 'build_indexes sets wait to false by default' do
    migration = described_class.new

    expect(migration).to receive(:execute_operation) do |operation|
      expect(operation.index_names).to eq([:type_company])
      expect(operation.wait).to be(false)
    end

    migration.build_indexes(:type_company)
  end

  it 'build_indexes sets wait to true when provided' do
    migration = described_class.new

    expect(migration).to receive(:execute_operation) do |operation|
      expect(operation.index_names).to eq([:type_company])
      expect(operation.wait).to be(true)
    end

    migration.build_indexes(:type_company, wait: true)
  end

  it 'does not poll index states when build_indexes wait is false' do
    migration_class = Class.new(CouchbaseOrm::IndexMigration) do
      def up
        build_indexes :type_company
      end
    end

    cluster = instance_double(Couchbase::Cluster)
    allow(CouchbaseOrm::Connection).to receive(:cluster).and_return(cluster)

    expect(cluster).to receive(:query).with(<<~SQL.strip, instance_of(Couchbase::Options::Query))
      BUILD INDEX ON `fleet-prod`
      (
        `type_company`
      );
    SQL
    expect(cluster).not_to receive(:query).with(/FROM system:indexes/, instance_of(Couchbase::Options::Query))

    migration_class.new.migrate(:up)
  end

  it 'polls until all indexes are online when build_indexes wait is true' do
    migration_class = Class.new(CouchbaseOrm::IndexMigration) do
      def up
        build_indexes :type_company, :date_on_type, wait: true
      end
    end

    cluster = instance_double(Couchbase::Cluster)
    allow(CouchbaseOrm::Connection).to receive(:cluster).and_return(cluster)

    poll_count = 0
    allow(cluster).to receive(:query) do |query, _options|
      if query.start_with?('BUILD INDEX ON')
        instance_double(Couchbase::Cluster::QueryResult, rows: [])
      elsif query.include?('FROM system:indexes')
        poll_count += 1
        rows = if poll_count == 1
                 [
                   { 'name' => 'type_company', 'state' => 'online' },
                   { 'name' => 'date_on_type', 'state' => 'building' }
                 ]
               else
                 [
                   { 'name' => 'type_company', 'state' => 'online' },
                   { 'name' => 'date_on_type', 'state' => 'online' }
                 ]
               end
        instance_double(Couchbase::Cluster::QueryResult, rows: rows)
      end
    end

    migration = migration_class.new
    expect(migration).to receive(:sleep).once
    migration.migrate(:up)

    expect(poll_count).to eq(2)
  end

  it 'raises irreversible migration when build_indexes is used in change' do
    migration_class = Class.new(CouchbaseOrm::IndexMigration) do
      def change
        build_indexes :type_company
      end
    end

    expect { migration_class.new.migrate(:down) }
      .to raise_error(CouchbaseOrm::IndexMigration::IrreversibleMigration)
  end
end
