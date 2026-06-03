# CouchbaseORM Index Migrations

## Motivation

CouchbaseORM currently does not provide a mechanism to version and manage indexes.

Users are responsible for maintaining large collections of N1QL statements manually, making it difficult to:

* evolve indexes over time;
* synchronize multiple environments;
* rollback changes;
* keep index definitions close to application code.

This feature introduces index migrations inspired by ActiveRecord.

## Goals

* Provide versioned index migrations.
* Follow ActiveRecord conventions as closely as possible.
* Keep implementation simple.
* Avoid schema diffing.
* Make migrations the source of truth.
* Support rollback.

## Non Goals

The following are explicitly out of scope:

* automatic comparison with `system:indexes`;
* automatic detection of index changes;
* schema dumping;
* index dependency analysis;
* index renaming support;
* index synchronization with existing clusters.

Users are expected to explicitly create migrations describing changes.

---

# Configuration

```ruby
CouchbaseOrm.configure do |config|
  config.index.bucket = "fleet-prod"
  config.index.num_replica = 1
  config.index.defer_build = true
end
```

Supported settings:

| Setting     | Default  |
| ----------- | -------- |
| bucket      | required |
| num_replica | 0        |
| defer_build | true     |

These values are automatically applied to every index created by migrations.

---

# Migration Files

Index migrations live in:

```text
db/indexes
```

Example:

```text
db/indexes/
  20250808110000_initial_indexes.rb
  20250808120000_add_workflow_index.rb
```

---

# Base Class

```ruby
class InitialIndexes < CouchbaseOrm::IndexMigration
end
```

---

# DSL

## add_index

```ruby
add_index(
  :type_company,
  keys: [:type, :company_id],
  where: "type is valued and company_id is valued"
)
```

Produces:

```sql
CREATE INDEX `type_company`
ON `bucket`(`type`,`company_id`)
WHERE (type is valued and company_id is valued)
WITH {
  "defer_build": true,
  "num_replica": 1
}
```

---

## remove_index

```ruby
remove_index :type_company
```

Produces:

```sql
DROP INDEX `bucket`.`type_company`
```

---

# Reversible Migrations

Simple migrations may use `change`.

```ruby
class InitialIndexes < CouchbaseOrm::IndexMigration
  def change
    add_index(
      :type_company,
      keys: [:type, :company_id],
      where: "type is valued and company_id is valued"
    )
  end
end
```

Rollback automatically performs:

```ruby
remove_index :type_company
```

---

Complex migrations may define:

```ruby
def up
end

def down
end
```

Example:

```ruby
class ChangeFleetByCompanyIndex < CouchbaseOrm::IndexMigration
  def up
    remove_index :fleet_by_company

    add_index(
      :fleet_by_company,
      keys: [:type, :company_id],
      where: "type is valued and company_id is valued"
    )
  end

  def down
    remove_index :fleet_by_company

    add_index(
      :fleet_by_company,
      keys: [:company_id, :type],
      where: "type is valued and company_id is valued"
    )
  end
end
```

---

# Migration State

Executed migrations are stored in a dedicated document:

```text
couchbaseorm::index_schema_migrations
```

Structure:

```json
{
  "versions": [
    "20250808110000",
    "20250808120000"
  ]
}
```

---

# Migrator

```ruby
CouchbaseOrm::IndexMigrator.migrate
```

Runs pending migrations.

---

Rollback:

```ruby
CouchbaseOrm::IndexMigrator.rollback
```

Rolls back the latest migration.

---

Status:

```ruby
CouchbaseOrm::IndexMigrator.status
```

Returns:

```
up     20250808110000 InitialIndexes
up     20250808120000 AddWorkflowIndex
down   20250808130000 ChangeFleetByCompanyIndex
```

---

# Generator

Generate migration:

```bash
bundle exec couchbaseorm index:generate AddWorkflowIndex
```

Creates:

```text
db/indexes/20250808130000_add_workflow_index.rb
```

with:

```ruby
class AddWorkflowIndex < CouchbaseOrm::IndexMigration
  def change
  end
end
```

---

# Rake Tasks

```bash
bundle exec couchbaseorm index:migrate
bundle exec couchbaseorm index:rollback
bundle exec couchbaseorm index:status
bundle exec couchbaseorm index:generate NAME=AddWorkflowIndex
```

---

# Future Extensions

Possible future additions:

* BUILD INDEX support;
* batch builds;
* scoped indexes;
* collections and scopes support;
* schema dump;
* automatic comparison with `system:indexes`.

These features are intentionally excluded from the first implementation.
