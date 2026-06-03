# Spec: Deferred Index Build Support

## Motivation

Couchbase supports deferred index creation:

```sql
CREATE INDEX ...
WITH { "defer_build": true }
```

followed by:

```sql
BUILD INDEX ON `bucket`(...);
```

CouchbaseORM should provide a simple and explicit way to perform these operations.

---

# Goals

* Support deferred indexes.
* Support explicit BUILD INDEX operations.
* Avoid hidden behavior.
* Stay close to ActiveRecord.

---

# DSL

## add_index

Immediate index:

```ruby
add_index(
  :type_company,
  keys: [:type, :company_id],
  where: "type is valued and company_id is valued"
)
```

Generates:

```sql
CREATE INDEX ...
```

---

Deferred index:

```ruby
add_index(
  :type_company,
  keys: [:type, :company_id],
  where: "type is valued and company_id is valued",
  defer_build: true
)
```

Generates:

```sql
CREATE INDEX ...
WITH {
  "defer_build": true,
  "num_replica": 1
}
```

---

## build_indexes

```ruby
build_indexes :type_company, :date_on_type
```

Generates:

```sql
BUILD INDEX ON `bucket`
(
  `type_company`,
  `date_on_type`
);
```

---

# Example

```ruby
class InitialIndexes < CouchbaseOrm::IndexMigration
  def change
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
end
```

Execution:

```sql
CREATE INDEX `type_company`
...
WITH { "defer_build": true, "num_replica": 1 };

CREATE INDEX `date_on_type`
...
WITH { "defer_build": true, "num_replica": 1 };

BUILD INDEX ON `bucket`
(
  `type_company`,
  `date_on_type`
);
```

---

# Reversibility

`add_index(..., defer_build: true)` is reversible.

Rollback executes:

```sql
DROP INDEX ...
```

`build_indexes` is irreversible.

Therefore:

```ruby
def change
  build_indexes :type_company
end
```

raises:

```ruby
CouchbaseOrm::IrreversibleMigration
```

during rollback.

Complex migrations requiring `build_indexes` should use:

```ruby
def up
end

def down
end
```

---

# Acceptance Criteria

Given:

```ruby
add_index :type_company,
  keys: [:type, :company_id],
  defer_build: true

add_index :date_on_type,
  keys: [:date],
  defer_build: true

build_indexes :type_company, :date_on_type
```

Then:

```sql
BUILD INDEX ON `bucket`
(
  `type_company`,
  `date_on_type`
);
```

is executed.

No internal tracking of deferred indexes is performed.
