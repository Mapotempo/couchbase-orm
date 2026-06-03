# Spec: Initial Index Migration Generation

## Motivation

Many existing Couchbase clusters already contain a large number of indexes created manually over time.

When adopting CouchbaseORM index migrations, users should be able to bootstrap their migration history from the indexes already present in production.

This allows:

* creating new environments (development, staging) with the same indexes as production;
* versioning existing indexes;
* progressively adopting index migrations without recreating production indexes.

---

# Goals

* Generate an initial migration from existing indexes.
* Support gradual adoption of index migrations.
* Preserve existing production indexes.
* Allow development and staging environments to recreate indexes from migrations.
* Stay close to the Rails philosophy.

---

# Non-Goals

* Synchronizing indexes automatically.
* Comparing migration definitions with the cluster.
* Updating existing indexes.
* Detecting unused indexes.
* Replacing future migrations.

---

# Command

```bash
bundle exec couchbaseorm index:dump
```

Generates a migration representing the current state of indexes for the configured bucket.

---

# Generated Migration

By default:

```text
db/indexes/
  20260810120000_initial_indexes.rb
```

Example:

```ruby
class InitialIndexes < CouchbaseOrm::IndexMigration
  def up
    add_index(
      :date_on_type,
      keys: [:date],
      where: "type is valued and date is valued",
      defer_build: true
    )

    add_index(
      :type_company,
      keys: [:type, :company_id],
      where: "type is valued and company_id is valued",
      defer_build: true
    )

    add_index(
      :type_company_external_ref_on_route,
      keys: [:type, :company_id, :external_ref],
      where: "type = 'route'",
      defer_build: true
    )

    build_indexes(
      :date_on_type,
      :type_company,
      :type_company_external_ref_on_route
    )
  end

  def down
    remove_index :type_company_external_ref_on_route
    remove_index :type_company
    remove_index :date_on_type
  end
end
```

---

# Source

Indexes are extracted from:

```sql
SELECT *
FROM system:indexes
WHERE keyspace_id = bucket_name
```

Only indexes belonging to the configured bucket are considered.

Primary indexes are ignored.

Indexes are ordered alphabetically by name to ensure deterministic output.

---

# Deferred Build

All generated indexes use:

```ruby
defer_build: true
```

A single:

```ruby
build_indexes(...)
```

statement is generated after all indexes.

This minimizes rebuild time when creating new environments.

---

# Migration Name

Default:

```text
InitialIndexes
```

Custom name:

```bash
bundle exec couchbaseorm index:dump NAME=FleetIndexes
```

Generates:

```ruby
class FleetIndexes < CouchbaseOrm::IndexMigration
end
```

---

# Production Adoption

After generating the migration, production users may mark it as executed without creating indexes again.

Example:

```bash
bundle exec couchbaseorm index:adopt
```

This command inserts the migration version into:

```ruby
CouchbaseOrm::IndexSchemaMigration
```

without executing the migration.

No indexes are created or modified.

---

# Development and Staging

In development or staging:

```bash
bundle exec couchbaseorm index:migrate
```

creates all indexes defined by the generated migration.

This ensures environments have the same index structure as production.

---

# Acceptance Criteria

## Dump Existing Indexes

Given a bucket containing:

* date_on_type
* type_company
* type_company_external_ref_on_route

When:

```bash
bundle exec couchbaseorm index:dump
```

Then:

* an initial migration file is created;
* all indexes are represented with `add_index`;
* indexes are sorted by name.

---

## Primary Indexes

Given a primary index exists,

When:

```bash
bundle exec couchbaseorm index:dump
```

Then the primary index is ignored.

---

## Deferred Build

Generated indexes contain:

```ruby
defer_build: true
```

and a single:

```ruby
build_indexes(...)
```

statement is generated.

---

## Deterministic Output

Running:

```bash
bundle exec couchbaseorm index:dump
```

multiple times without cluster changes produces identical migration contents.

---

## Production Adoption

Given the initial migration exists,

When:

```bash
bundle exec couchbaseorm index:adopt
```

is executed,

Then:

* the migration version is marked as executed;
* no indexes are created;
* no indexes are removed.

---

# Future Extensions

Possible future additions:

* `index:diff`
* `index:status`
* `index:cleanup`
* support for scopes and collections
* support for primary indexes
* schema dump (`db/index_schema.rb`)
* import from multiple buckets
