# Implementation Plan: Index Schema Dump and Load

## Goal

Introduce:

```bash
bundle exec couchbaseorm index:schema:dump
bundle exec couchbaseorm index:schema:load
```

and the schema file:

```text
db/index_schema.rb
```

similar to ActiveRecord's:

```text
db/schema.rb
```

The schema file represents the current index state and avoids replaying the entire migration history for fresh installations.

---

# Phase 1 — Introduce IndexSchema

## Goal

Create:

```ruby
CouchbaseOrm::IndexSchema
```

similar to:

```ruby
ActiveRecord::Schema
```

Support:

```ruby
CouchbaseOrm::IndexSchema.define(version: 20260101120000) do
  add_index :type_company,
    keys: [:type, :company_id]

  add_index :date_on_type,
    keys: [:date]
end
```

---

# Phase 2 — Introduce Schema Definition

## Goal

Represent the current index schema in memory.

Create:

```ruby
CouchbaseOrm::IndexSchema::Definition
```

Responsibilities:

```ruby
add_index
remove_index
rename_index
```

Example:

```ruby
definition.indexes
```

returns:

```ruby
{
  type_company: {
    keys: [:type, :company_id]
  },

  date_on_type: {
    keys: [:date]
  }
}
```

---

# Phase 3 — Replay Migrations In Memory

## Goal

Compute the final schema.

Load:

```text
db/indexes/*.rb
```

Replay operations against:

```ruby
IndexSchema::Definition
```

Supported operations:

```ruby
add_index
remove_index
rename_index
```

Ignored:

```ruby
build_indexes
```

because build operations do not affect schema state.

---

# Phase 4 — Generate index_schema.rb

## Goal

Create:

```text
db/index_schema.rb
```

Example:

```ruby
CouchbaseOrm::IndexSchema.define(version: 20260101120000) do
  add_index :type_company,
    keys: [:type, :company_id]

  add_index :date_on_type,
    keys: [:date]
end
```

Preserve:

```ruby
keys
where
num_replica
defer_build
```

Output should be deterministic and sorted by index name.

---

# Phase 5 — Introduce Schema Dumper

## Goal

Encapsulate schema generation.

Create:

```ruby
CouchbaseOrm::IndexSchema::Dumper
```

Responsibilities:

```ruby
dump
```

Workflow:

```text
Load migrations
↓
Replay in memory
↓
Build Definition
↓
Generate Ruby DSL
↓
Write db/index_schema.rb
```

---

# Phase 6 — Add index:schema:dump Task

## Goal

Expose:

```bash
bundle exec couchbaseorm index:schema:dump
```

Behavior:

```text
Load migrations
↓
Compute final schema
↓
Generate db/index_schema.rb
```

No database access is required.

---

# Phase 7 — Schema Loader

## Goal

Load schema directly.

Create:

```ruby
CouchbaseOrm::IndexSchema::Loader
```

Responsibilities:

```ruby
load
```

Workflow:

```text
Load db/index_schema.rb
↓
Execute add_index operations
↓
Collect deferred indexes
↓
Execute BUILD INDEX
```

Migration files are not loaded.

---

# Phase 8 — Add index:schema:load Task

## Goal

Expose:

```bash
bundle exec couchbaseorm index:schema:load
```

Behavior:

```text
Load db/index_schema.rb
↓
Create indexes
↓
Build deferred indexes
```

No migration replay occurs.

---

# Phase 9 — Schema Version

## Goal

Preserve schema version.

Generated file:

```ruby
CouchbaseOrm::IndexSchema.define(
  version: 20260101120000
) do
  ...
end
```

Version corresponds to the latest migration version.

Similar to:

```ruby
ActiveRecord::Schema.define(version: ...)
```

---

# Phase 10 — Tests

## Definition

Verify:

```ruby
add_index
remove_index
rename_index
```

correctly update:

```ruby
definition.indexes
```

---

## Dump

Given:

```ruby
add_index :type_company,
  keys: [:company_id, :type]

remove_index :type_company

add_index :type_company,
  keys: [:type, :company_id]
```

Expect:

```ruby
index_schema.rb
```

contains:

```ruby
add_index :type_company,
  keys: [:type, :company_id]
```

and no intermediate operations.

---

## Load

Given:

```ruby
CouchbaseOrm::IndexSchema.define do
  add_index :type_company,
    keys: [:type, :company_id]
end
```

Expect:

```bash
bundle exec couchbaseorm index:schema:load
```

to create the index without loading migration files.

---

## Deferred indexes

Given:

```ruby
add_index :type_company,
  keys: [:type],
  defer_build: true

add_index :date_on_type,
  keys: [:date],
  defer_build: true
```

Expect:

```ruby
build_indexes(
  :date_on_type,
  :type_company
)
```

to be executed automatically during schema loading.

---

## Deterministic output

Running:

```bash
bundle exec couchbaseorm index:schema:dump
```

twice without migration changes should produce identical files.

---

# V1 Complete

Supported:

* `index:schema:dump`
* `index:schema:load`
* `db/index_schema.rb`
* in-memory migration replay
* deterministic schema generation
* schema version
* deferred index build during schema load

Not supported:

* comparison with `system:indexes`
* dry-run mode
* comments
* scopes and collections
* metadata
* `index:schema:diff`

The design intentionally mirrors ActiveRecord's `schema.rb` and `db:schema:load` philosophy.
