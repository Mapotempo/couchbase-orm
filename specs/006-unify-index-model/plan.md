# Implementation Plan: Unified Index Definition Model

## Goal

Introduce a single model:

```ruby
CouchbaseOrm::IndexDefinition
```

used by:

* migrations;
* operations;
* query generation;
* schema dump;
* schema load.

This avoids duplicated models and keeps index metadata centralized.

---

## Phase 1 — Add `IndexDefinition`

Create:

```ruby
CouchbaseOrm::IndexDefinition
```

Attributes:

```ruby
name
keys
where
defer_build
num_replica
```

Example:

```ruby
CouchbaseOrm::IndexDefinition.new(
  name: :type_company,
  keys: [:type, :company_id],
  where: "type is valued and company_id is valued",
  defer_build: true,
  num_replica: 1
)
```

---

## Phase 2 — Update `add_index`

Change the migration DSL so:

```ruby
add_index :type_company,
  keys: [:type, :company_id],
  where: "type is valued and company_id is valued",
  defer_build: true
```

creates:

```ruby
IndexDefinition.new(...)
```

then records:

```ruby
Operations::CreateIndex.new(index_definition)
```

---

## Phase 3 — Rename `AddIndex` Operation

Replace:

```ruby
Operations::AddIndex
```

with:

```ruby
Operations::CreateIndex
```

`CreateIndex` should contain only:

```ruby
index_definition
```

This makes the operation describe the action and the model describe the index.

---

## Phase 4 — Update QueryBuilder

Before:

```ruby
create_index(name:, keys:, where:, defer_build:, num_replica:)
```

After:

```ruby
create_index(index_definition)
```

`QueryBuilder` reads directly from:

```ruby
index_definition.name
index_definition.keys
index_definition.where
index_definition.defer_build
index_definition.num_replica
```

---

## Phase 5 — Keep Other Operations Simple

Keep:

```ruby
DropIndex.new(:type_company)
RenameIndex.new(:old_name, :new_name)
BuildIndexes.new([:index_a, :index_b], wait: true)
```

Only `CreateIndex` needs a full `IndexDefinition`.

---

## Phase 6 — Update Command Recorder

Ensure rollback still works:

```ruby
CreateIndex(index_definition)
```

reverses to:

```ruby
DropIndex(index_definition.name)
```

`DropIndex` remains reversible only when enough information is known, otherwise it behaves as currently defined.

---

## Phase 7 — Use `Hash<Symbol, IndexDefinition>` for Schema State

During schema dump, represent the current schema as:

```ruby
{
  type_company: IndexDefinition.new(...),
  date_on_type: IndexDefinition.new(...)
}
```

Operations apply as:

```ruby
CreateIndex => indexes[index.name] = index
DropIndex   => indexes.delete(name)
RenameIndex => indexes[new_name] = indexes.delete(old_name)
BuildIndexes => ignored
```

No `IndexSchema::Definition` class is needed.

---

## Phase 8 — Update Schema Dumper

The dumper receives:

```ruby
Hash<Symbol, IndexDefinition>
```

and generates:

```ruby
CouchbaseOrm::IndexSchema.define(version: 20260101120000) do
  add_index :type_company,
    keys: [:type, :company_id],
    where: "type is valued and company_id is valued",
    defer_build: true
end
```

Sort indexes by name for deterministic output.

---

## Phase 9 — Update Schema Loader

When loading `db/index_schema.rb`, reuse the normal DSL:

```ruby
add_index :type_company,
  keys: [:type, :company_id]
```

Internally it creates:

```ruby
IndexDefinition
```

and executes:

```ruby
CreateIndex
```

---

## Phase 10 — Tests

Cover:

* `IndexDefinition` attributes.
* `add_index` creates `IndexDefinition`.
* `CreateIndex` generates the same SQL as before.
* rollback of `CreateIndex` drops the index.
* schema dump uses `Hash<Symbol, IndexDefinition>`.
* schema load creates indexes through `CreateIndex`.
* no `IndexSchema::Definition` model is introduced.

---

## V1 Complete

Supported:

* single index metadata model;
* migrations using `IndexDefinition`;
* schema dump/load using `IndexDefinition`;
* query generation from `IndexDefinition`;
* no duplicated schema definition model.

Future index options should be added to `IndexDefinition` first.
