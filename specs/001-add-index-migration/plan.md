# Implementation Plan: Index Migrations

## Phase 1 — Core DSL

### Goal

Allow users to define index migrations.

### Tasks

#### Create base class

```ruby
CouchbaseOrm::IndexMigration
```

Support:

* `change`
* `up`
* `down`

#### Add commands

```ruby
add_index(
  :type_company,
  keys: [:type, :company_id],
  where: "type is valued and company_id is valued"
)

remove_index(:type_company)
```

#### Create operation objects

```ruby
CouchbaseOrm::IndexMigration::Operations::AddIndex
CouchbaseOrm::IndexMigration::Operations::RemoveIndex
```

Operations should be reversible.

---

## Phase 2 — Query Generation

### Goal

Convert DSL into N1QL.

### Tasks

Create:

```ruby
CouchbaseOrm::IndexMigration::QueryBuilder
```

Generate:

```sql
CREATE INDEX ...
DROP INDEX ...
```

Use configuration:

```ruby
config.index.bucket
config.index.num_replica
config.index.defer_build
```

---

## Phase 3 — Migration State

### Goal

Track executed migrations.

### Tasks

Implement:

```ruby
CouchbaseOrm::IndexSchemaMigration
```

Document key:

```text
couchbaseorm::index_schema_migrations
```

Structure:

```json
{
  "versions": []
}
```

Methods:

```ruby
versions
add_version(version)
remove_version(version)
```

---

## Phase 4 — Migration Context

### Goal

Discover migration files.

### Tasks

Implement:

```ruby
CouchbaseOrm::IndexMigrationContext
```

Responsibilities:

* load files from

```text
db/indexes
```

* sort migrations
* return pending migrations

---

## Phase 5 — Migrator

### Goal

Execute migrations.

### Tasks

Implement:

```ruby
CouchbaseOrm::IndexMigrator
```

Methods:

```ruby
migrate
rollback
status
```

Workflow:

1. load migration files
2. load executed versions
3. execute pending migrations
4. save version

Rollback:

1. find latest version
2. execute inverse migration
3. remove version

---

## Phase 6 — Automatic Reversal

### Goal

Support:

```ruby
def change
```

Tasks:

Implement:

```ruby
CouchbaseOrm::IndexMigration::CommandRecorder
```

Like ActiveRecord.

Example:

```ruby
add_index(...)
```

becomes

```ruby
remove_index(...)
```

during rollback.

---

## Phase 7 — CLI Generator

### Goal

Generate migration files.

Command:

```bash
bundle exec couchbaseorm index:generate AddWorkflowIndex
```

Produces:

```text
db/indexes/
  20260803104500_add_workflow_index.rb
```

Content:

```ruby
class AddWorkflowIndex < CouchbaseOrm::IndexMigration
  def change
  end
end
```

---

## Phase 8 — Tasks

Add:

```bash
bundle exec couchbaseorm index:migrate

bundle exec couchbaseorm index:rollback

bundle exec couchbaseorm index:status
```

---

# V1 Complete

Supported:

* add_index
* remove_index
* change
* up/down
* rollback
* status
* generators

Not supported:

* rename_index
* build indexes
* collections/scopes
* schema dump
* diff with system:indexes
* automatic synchronization

---

# Future Phases

## V2

```ruby
rename_index
```

## V3

```ruby
build_indexes
```

Generate:

```sql
BUILD INDEX ON bucket(...)
```

## V4

Collections and scopes support.

## V5

Schema dump:

```ruby
db/index_schema.rb
```

## V6

Index diff:

```bash
bundle exec couchbaseorm index:diff
```
