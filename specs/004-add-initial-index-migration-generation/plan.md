# Implementation Plan: Initial Index Migration Generation

## Goal

Allow existing Couchbase clusters to bootstrap CouchbaseORM index migrations from the indexes already present in production.

This enables:

* adoption of index migrations on existing projects;
* recreation of indexes in development and staging environments;
* future index evolution through regular migrations.

---

# Phase 1 — Index Introspection

## Goal

Read index definitions from the cluster.

## Tasks

Create:

```ruby
CouchbaseOrm::IndexMigration::IndexIntrospector
```

Responsibilities:

* query `system:indexes`;
* filter indexes belonging to the configured bucket;
* ignore primary indexes;
* normalize metadata;
* sort indexes alphabetically.

Query:

```sql
SELECT *
FROM system:indexes
WHERE keyspace_id = $bucket
```

Returns:

```ruby
[
  {
    name: "date_on_type",
    index_key: [...],
    condition: "...",
    state: "online"
  },
  ...
]
```

---

# Phase 2 — Index Definition Model

## Goal

Represent indexes independently from Couchbase metadata.

## Tasks

Create:

```ruby
CouchbaseOrm::IndexMigration::IndexDefinition
```

Attributes:

```ruby
name
keys
where
```

Responsibilities:

* parse `index_key`;
* extract WHERE clause;
* ignore runtime properties;
* provide deterministic ordering.

---

# Phase 3 — Migration Generator

## Goal

Generate an InitialIndexes migration.

## Tasks

Create:

```ruby
CouchbaseOrm::IndexMigration::MigrationGenerator
```

Input:

```ruby
Array<IndexDefinition>
```

Output:

```ruby
class InitialIndexes < CouchbaseOrm::IndexMigration
  def up
    ...
  end

  def down
    ...
  end
end
```

---

# Phase 4 — Generate add_index Statements

## Goal

Convert index definitions into DSL.

Example:

Cluster:

```sql
CREATE INDEX type_company
ON bucket(type, company_id)
WHERE type IS VALUED;
```

Produces:

```ruby
add_index(
  :type_company,
  keys: [:type, :company_id],
  where: "type IS VALUED",
  defer_build: true
)
```

Rules:

* generate indexes alphabetically;
* always use:

```ruby
defer_build: true
```

to minimize build time.

---

# Phase 5 — Generate build_indexes Statement

## Goal

Build indexes in a single operation.

Example:

```ruby
build_indexes(
  :date_on_type,
  :type_company,
  :workflow_index
)
```

Responsibilities:

* use the same alphabetical ordering;
* generate a single BUILD INDEX operation.

---

# Phase 6 — Generate Down Migration

## Goal

Support rollback.

Example:

```ruby
def down
  remove_index :workflow_index
  remove_index :type_company
  remove_index :date_on_type
end
```

Rules:

* reverse creation order;
* use deterministic ordering.

---

# Phase 7 — Dump Task

## Goal

Expose generation through CLI.

Command:

```bash
bundle exec couchbaseorm index:dump
```

Workflow:

1. load bucket configuration;
2. introspect indexes;
3. build index definitions;
4. generate migration source;
5. create:

```text
db/indexes/YYYYMMDDHHMMSS_initial_indexes.rb
```

---

# Phase 8 — Custom Migration Name

## Goal

Support:

```bash
bundle exec couchbaseorm index:dump NAME=FleetIndexes
```

Produces:

```ruby
class FleetIndexes < CouchbaseOrm::IndexMigration
end
```

File:

```text
db/indexes/YYYYMMDDHHMMSS_fleet_indexes.rb
```

Default:

```ruby
InitialIndexes
```

---

# Phase 9 — Adopt Command

## Goal

Mark generated migration as already executed.

Command:

```bash
bundle exec couchbaseorm index:adopt
```

Responsibilities:

* locate latest index migration;
* extract version;
* insert version into:

```ruby
CouchbaseOrm::IndexSchemaMigration
```

without executing the migration.

No indexes are modified.

---

# Phase 10 — Tests

## IndexIntrospector

* filters bucket;
* ignores primary indexes;
* sorts indexes by name.

---

## MigrationGenerator

Given:

```ruby
[
  date_on_type,
  type_company
]
```

Produces:

```ruby
add_index(...)
add_index(...)

build_indexes(...)
```

with:

```ruby
defer_build: true
```

---

## Down Migration

Produces:

```ruby
remove_index(...)
```

in reverse order.

---

## Deterministic Output

Running:

```bash
bundle exec couchbaseorm index:dump
```

twice without cluster changes generates identical migration content.

---

## Adopt

Given:

```text
20260810120000_initial_indexes.rb
```

When:

```bash
bundle exec couchbaseorm index:adopt
```

Then:

* version `20260810120000` is inserted into
  `CouchbaseOrm::IndexSchemaMigration`;
* no queries are executed against indexes.

---

# V1 Complete

Supported:

* existing cluster introspection;
* migration generation;
* deterministic output;
* deferred index creation;
* single BUILD INDEX operation;
* rollback support;
* production adoption.

Not Supported:

* scopes and collections;
* primary indexes;
* index diff;
* index status;
* multiple buckets;
* schema dump;
* automatic synchronization.

The implementation intentionally focuses on enabling existing production clusters to adopt CouchbaseORM index migrations with minimal risk and maximum simplicity.
