# Implementation Plan: Deferred Index Build Support

## Goal

Support deferred index creation and explicit `BUILD INDEX` operations while keeping the API simple and close to ActiveRecord.

Example:

```ruby
class InitialIndexes < CouchbaseOrm::IndexMigration
  def up
    add_index(
      :type_company,
      keys: [:type, :company_id],
      where: "type is valued and company_id is valued",
      defer_build: true
    )

    add_index(
      :date_on_type,
      keys: [:date],
      where: "type is valued and date is valued",
      defer_build: true
    )

    build_indexes(
      :type_company,
      :date_on_type
    )
  end

  def down
    remove_index :date_on_type
    remove_index :type_company
  end
end
```

---

# Phase 1 — Extend AddIndex

## Goal

Allow indexes to be created with `defer_build: true`.

## Tasks

### Add option

```ruby
add_index(
  :type_company,
  keys: [:type, :company_id],
  defer_build: true
)
```

### Extend AddIndex operation

```ruby
CouchbaseOrm::IndexMigration::Operations::AddIndex
```

with:

```ruby
name
keys
where
defer_build
```

### Update QueryBuilder

Current:

```sql
CREATE INDEX ...
```

New:

```sql
CREATE INDEX ...
WITH {
  "defer_build": true,
  "num_replica": 1
}
```

when:

```ruby
defer_build == true
```

Otherwise:

```sql
CREATE INDEX ...
```

or:

```sql
WITH {
  "num_replica": 1
}
```

depending on current implementation.

---

# Phase 2 — BuildIndexes Operation

## Goal

Introduce explicit BUILD INDEX support.

## Create operation

```ruby
CouchbaseOrm::IndexMigration::Operations::BuildIndexes
```

Attributes:

```ruby
index_names
```

Example:

```ruby
BuildIndexes.new(
  [:type_company, :date_on_type]
)
```

---

## Validation

Raise:

```ruby
ArgumentError
```

when:

```ruby
build_indexes()
```

receives no index names.

---

# Phase 3 — Query Builder

## Goal

Generate BUILD INDEX statements.

Input:

```ruby
BuildIndexes.new(
  [:type_company, :date_on_type]
)
```

Output:

```sql
BUILD INDEX ON `bucket`
(
  `type_company`,
  `date_on_type`
);
```

Bucket comes from:

```ruby
CouchbaseOrm.config.index.bucket
```

---

# Phase 4 — DSL

## Goal

Expose the command in migrations.

Add:

```ruby
build_indexes(*index_names)
```

Example:

```ruby
build_indexes(
  :type_company,
  :date_on_type
)
```

Internally:

```ruby
record(
  Operations::BuildIndexes.new(index_names)
)
```

---

# Phase 5 — Command Recorder

## Goal

Support rollback behavior.

Since:

```sql
BUILD INDEX
```

cannot be reversed,

register:

```ruby
build_indexes
```

as irreversible.

Rollback of:

```ruby
def change
  build_indexes :type_company
end
```

raises:

```ruby
CouchbaseOrm::IrreversibleMigration
```

similar to:

```ruby
execute(...)
```

in ActiveRecord.

---

# Phase 6 — Execution

## Goal

Execute BUILD INDEX queries.

Example migration:

```ruby
def up
  add_index(
    :type_company,
    keys: [:type, :company_id],
    defer_build: true
  )

  add_index(
    :date_on_type,
    keys: [:date],
    defer_build: true
  )

  build_indexes(
    :type_company,
    :date_on_type
  )
end
```

Execution order:

```sql
CREATE INDEX ...

CREATE INDEX ...

BUILD INDEX ON `bucket`
(
  `type_company`,
  `date_on_type`
);
```

---

# Phase 7 — Tests

## AddIndex

### immediate index

```ruby
add_index(
  :type_company,
  keys: [:type]
)
```

does not generate:

```json
{
  "defer_build": true
}
```

---

### deferred index

```ruby
add_index(
  :type_company,
  keys: [:type],
  defer_build: true
)
```

generates:

```json
{
  "defer_build": true
}
```

---

## BuildIndexes

Input:

```ruby
build_indexes(
  :type_company,
  :date_on_type
)
```

Output:

```sql
BUILD INDEX ON `bucket`
(
  `type_company`,
  `date_on_type`
);
```

---

## Empty build

```ruby
build_indexes()
```

raises:

```ruby
ArgumentError
```

---

## Reversibility

Migration:

```ruby
def change
  build_indexes :type_company
end
```

Rollback raises:

```ruby
CouchbaseOrm::IrreversibleMigration
```

---

# V1 Complete

Supported:

* `add_index(..., defer_build: true)`
* `build_indexes(*names)`
* rollback protection

Not supported:

* automatic build detection
* build progress monitoring
* waiting for indexes to become online
* querying `system:indexes`
* build all deferred indexes
* grouped builds across migrations

The design intentionally favors simplicity and explicit behavior, following the philosophy of ActiveRecord migrations.
