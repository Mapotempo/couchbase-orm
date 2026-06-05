# Spec: Index Schema Dump and Load

## Motivation

Over time, index migrations accumulate:

```text id="mzkd9r"
db/indexes/

20250101000000_initial_indexes.rb
20250102000000_add_route_indexes.rb
20250103000000_add_workflow_indexes.rb
20250104000000_change_company_index.rb
...
```

Replaying every migration becomes increasingly expensive for fresh installations.

ActiveRecord solves this problem with:

```text id="tyk4i6"
db/schema.rb
```

which represents the current database state independently from migration history.

CouchbaseORM should provide the same capability for indexes.

---

# Goals

* Provide a snapshot of the current index schema.
* Speed up fresh installations.
* Preserve migration history.
* Stay close to ActiveRecord.
* Keep migrations as the source of truth.

---

# Non-Goals

* Rewriting migration history.
* Automatic compaction.
* Comparing against `system:indexes`.
* Removing old migrations.
* Replacing index migrations.

---

# Commands

## Dump schema

```bash id="wxwklv"
bundle exec couchbaseorm index:schema:dump
```

Generates:

```text id="pjwdix"
db/index_schema.rb
```

---

## Load schema

```bash id="l6tkhg"
bundle exec couchbaseorm index:schema:load
```

Loads all indexes defined in:

```text id="7jbv5k"
db/index_schema.rb
```

without replaying historical migrations.

---

# Schema File

Default location:

```text id="17oqyj"
db/index_schema.rb
```

Example:

```ruby id="qj5dvf"
CouchbaseOrm::IndexSchema.define(version: 2026_01_01_120000) do
  add_index :type_company,
    keys: [:type, :company_id],
    where: "type is valued and company_id is valued"

  add_index :date_on_type,
    keys: [:date]

  add_index :workflow_by_company,
    keys: [:company_id],
    where: "type = 'workflow'"
end
```

---

# Schema Version

The schema stores the latest migration version:

```ruby id="u22owj"
version: 2026_01_01_120000
```

similar to:

```ruby id="u6lbwy"
ActiveRecord::Schema.define(version: ...)
```

---

# IndexSchema DSL

Introduce:

```ruby id="b4obva"
CouchbaseOrm::IndexSchema
```

Example:

```ruby id="r9snbn"
CouchbaseOrm::IndexSchema.define(version: 2026_01_01_120000) do
  add_index :type_company,
    keys: [:type, :company_id]

  add_index :date_on_type,
    keys: [:date]
end
```

The DSL supports:

```ruby id="j9n2g9"
add_index
```

Index names can be symbols or strings.
For non-conventional names (for example with a hyphen `-`), use strings:

```ruby
add_index "type-company",
  keys: [:type, :company_id]
```

The same applies to `remove_index` and `rename_index`.

---

# Schema Dump

## Behavior

`index:schema:dump`:

1. Loads all migrations.
2. Replays them in memory.
3. Computes the final schema.
4. Generates:

```text id="pdikzq"
db/index_schema.rb
```

The generated schema contains only indexes that currently exist.

Intermediate operations are discarded.

---

## Example

Migrations:

```ruby id="5gohgq"
add_index :type_company,
  keys: [:company_id, :type]

remove_index :type_company

add_index :type_company,
  keys: [:type, :company_id]
```

Generated schema:

```ruby id="95nr5m"
CouchbaseOrm::IndexSchema.define(version: 2026_01_01_120000) do
  add_index :type_company,
    keys: [:type, :company_id]

  add_index "type-company",
    keys: [:type]
end
```

---

# Schema Load

## Behavior

`index:schema:load`:

1. Loads:

```text id="k0myly"
db/index_schema.rb
```

2. Executes:

```ruby id="a6n8vc"
add_index
```

operations.

3. Builds the indexes.

No migration files are replayed.

---

# Build Behavior

Indexes with:

```ruby id="gx9sx2"
defer_build: true
```

are collected and built together:

```ruby id="uwv48h"
build_indexes(
  :type_company,
  :date_on_type
)
```

This behavior is internal to schema loading.

---

# Internal Representation

Introduce:

```ruby id="sq97sj"
CouchbaseOrm::IndexSchema::Definition
```

Responsibilities:

```ruby id="x9h4da"
add_index
remove_index
rename_index
```

Example:

```ruby id="zn4wbm"
definition.indexes
```

returns:

```ruby id="cjlwm6"
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

# Supported Operations

Schema dump understands:

```ruby id="9j1tyk"
add_index
remove_index
rename_index
```

and preserves:

```ruby id="13vmb7"
keys
where
num_replica
defer_build
```

---

# Unsupported Operations

Schema dump ignores:

```ruby id="cc0m9x"
build_indexes
```

because build operations are runtime concerns and do not affect schema state.

---

# Relationship with Migrations

Migrations remain the source of truth.

The schema file is a snapshot.

Like ActiveRecord:

```text id="b5pp4d"
db/indexes/
```

contains history.

```text id="vsl7cx"
db/index_schema.rb
```

contains the current state.

---

# Acceptance Criteria

### Dump

Given:

```ruby id="rnxg8c"
add_index :type_company,
  keys: [:company_id, :type]

remove_index :type_company

add_index :type_company,
  keys: [:type, :company_id]
```

Then:

```text id="n9tn7l"
db/index_schema.rb
```

contains:

```ruby id="h6cbg7"
add_index :type_company,
  keys: [:type, :company_id]
```

and no intermediate operations.

---

### Load

Given:

```text id="t8p3l0"
db/index_schema.rb
```

Then:

```bash id="k2gszk"
bundle exec couchbaseorm index:schema:load
```

creates the indexes without replaying migration files.

---

# Future Extensions

Possible future additions:

* `index:schema:load:if_empty`
* support for scopes and collections
* `index:schema:dump --dry-run`
* `index:schema:diff`
* support for comments and metadata

The design intentionally mirrors ActiveRecord's `schema.rb` and `db:schema:load` philosophy.
