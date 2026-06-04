# Spec: Unified Index Definition Model

## Motivation

Several features require representing index metadata:

* migrations;
* schema dump;
* schema load;
* in-memory schema replay;
* query generation.

A naive implementation introduces multiple models describing the same concept:

```ruby id="tn7uh7"
Operations::AddIndex
IndexSchema::Definition
SchemaLoader::Definition
SchemaDumper::Definition
```

This duplicates responsibility and makes future evolution harder.

CouchbaseORM should use a single model to represent an index definition throughout the system.

---

# Goals

* Introduce a single source of truth for index metadata.
* Reuse the same model across migrations and schema dump/load.
* Minimize duplicated state.
* Stay close to ActiveRecord's architecture.
* Simplify future features.

---

# Non-Goals

* Changing the migration DSL.
* Changing query generation semantics.
* Adding support for new index features.

---

# IndexDefinition

Introduce:

```ruby id="t6j7rf"
CouchbaseOrm::IndexDefinition
```

Example:

```ruby id="l8l5y0"
IndexDefinition.new(
  name: :type_company,
  keys: [:type, :company_id],
  where: "type is valued and company_id is valued",
  defer_build: true,
  num_replica: 1
)
```

---

# Attributes

```ruby id="h42dfx"
name
keys
where
defer_build
num_replica
```

Example:

```ruby id="w6l9oq"
index.name
# => :type_company

index.keys
# => [:type, :company_id]

index.where
# => "type is valued and company_id is valued"

index.defer_build
# => true

index.num_replica
# => 1
```

---

# Operations

## CreateIndex

Introduce:

```ruby id="0h5egr"
CouchbaseOrm::IndexMigration::Operations::CreateIndex
```

which contains:

```ruby id="0ycb28"
index_definition
```

Example:

```ruby id="n4b0lj"
CreateIndex.new(
  IndexDefinition.new(...)
)
```

---

## DropIndex

```ruby id="ofmr0l"
DropIndex.new(
  :type_company
)
```

---

## RenameIndex

```ruby id="mw9b76"
RenameIndex.new(
  :old_name,
  :new_name
)
```

---

## BuildIndexes

```ruby id="vtjqao"
BuildIndexes.new(
  [:type_company],
  wait: true
)
```

---

# Migration DSL

Existing API remains unchanged:

```ruby id="8jlwmv"
add_index(
  :type_company,
  keys: [:type, :company_id],
  where: "type is valued and company_id is valued"
)
```

Internally:

```ruby id="mndddv"
IndexDefinition.new(...)
↓
CreateIndex.new(index_definition)
```

---

# Query Builder

Query generation uses:

```ruby id="fkpjlwm"
IndexDefinition
```

instead of individual arguments.

Example:

```ruby id="ubzfh8"
QueryBuilder.create_index(
  index_definition
)
```

Generates:

```sql id="61q2dz"
CREATE INDEX ...
```

---

# In-Memory Schema Representation

No dedicated schema model is introduced.

Current schema state is represented as:

```ruby id="s9k80g"
Hash<Symbol, IndexDefinition>
```

Example:

```ruby id="b7hl3n"
{
  type_company: IndexDefinition.new(...),

  date_on_type: IndexDefinition.new(...)
}
```

---

## add_index

Performs:

```ruby id="vgy9tw"
indexes[index_definition.name] = index_definition
```

---

## remove_index

Performs:

```ruby id="3bywmi"
indexes.delete(name)
```

---

## rename_index

Performs:

```ruby id="avhbgj"
indexes[new_name] = indexes.delete(old_name)
```

---

# Schema Dump

Schema dump serializes:

```ruby id="i1vp58"
Hash<Symbol, IndexDefinition>
```

into:

```ruby id="7klmcb"
CouchbaseOrm::IndexSchema.define(version: ...) do
  add_index ...
end
```

No intermediate model is required.

---

# Schema Load

Schema load creates:

```ruby id="4gq1l0"
IndexDefinition
```

objects and executes:

```ruby id="mhm0vl"
CreateIndex.new(index_definition)
```

No schema-specific representation exists.

---

# Command Recorder

Operations continue to be recorded as:

```ruby id="2lt4cc"
CreateIndex
DropIndex
RenameIndex
BuildIndexes
```

Rollback behavior remains unchanged.

---

# Acceptance Criteria

## Single Index Model

Only one class represents index metadata:

```ruby id="sy57rq"
CouchbaseOrm::IndexDefinition
```

---

## Query Builder

Receives:

```ruby id="3kh6yr"
IndexDefinition
```

instead of individual parameters.

---

## Schema Dump

Uses:

```ruby id="m8txp4"
Hash<Symbol, IndexDefinition>
```

without introducing:

```ruby id="ybryj0"
IndexSchema::Definition
```

---

## Schema Load

Recreates:

```ruby id="bsv6mp"
IndexDefinition
```

and executes:

```ruby id="c9c5p4"
CreateIndex
```

operations.

---

# Future Extensions

Future properties may be added to:

```ruby id="a74oj5"
IndexDefinition
```

such as:

```ruby id="2d0f4w"
condition
scope
collection
partition
comment
```

without requiring changes to migration, schema dump, schema load, or query generation.

The architecture intentionally favors a single model for index metadata and avoids duplicated representations of the same concept.
