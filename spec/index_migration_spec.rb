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
