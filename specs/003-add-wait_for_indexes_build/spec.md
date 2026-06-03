# Spec: Wait Support for `build_indexes`

## Motivation

`BUILD INDEX` in Couchbase is asynchronous.

Executing:

```sql
BUILD INDEX ON `bucket`(`type_company`);
```

returns immediately while the index may still be in the `building` state.

This is usually acceptable when creating new indexes, but can be dangerous when replacing an existing index:

```ruby
add_index :type_company_v2,
  keys: [:type, :company_id],
  defer_build: true

build_indexes :type_company_v2

remove_index :type_company
```

If the old index is removed before the new index becomes `online`, queries may fail or experience degraded performance.

CouchbaseORM should provide an explicit way to wait for indexes to become online.

---

# Goals

* Provide explicit waiting semantics.
* Keep waiting opt-in.
* Avoid introducing additional DSL methods.
* Keep the API simple and close to ActiveRecord.
* Prevent accidental production outages during index replacement.

---

# Non-Goals

* Automatically waiting after every build.
* Monitoring index progress.
* Configurable timeout.
* Rebuilding indexes automatically.
* Polling indexes outside explicit user requests.

---

# DSL

Current:

```ruby
build_indexes :type_company
```

New:

```ruby
build_indexes :type_company, wait: true
```

Multiple indexes:

```ruby
build_indexes :type_company,
              :date_on_type,
              wait: true
```

---

# Behavior

## wait: false (default)

```ruby
build_indexes :type_company
```

Generates:

```sql
BUILD INDEX ON `bucket`
(
  `type_company`
);
```

No additional polling is performed.

---

## wait: true

```ruby
build_indexes :type_company,
              wait: true
```

Execution flow:

1. Execute:

```sql
BUILD INDEX ON `bucket`
(
  `type_company`
);
```

2. Poll:

```sql
SELECT name, state
FROM system:indexes
WHERE keyspace_id = $bucket
AND name IN $index_names
```

3. Continue when every index reaches:

```text
online
```

---

# Polling Strategy

Polling interval:

```ruby
1.second
```

No timeout is applied.

The operation waits indefinitely until all indexes become online.

---

# Operation

Extend:

```ruby
CouchbaseOrm::IndexMigration::Operations::BuildIndexes
```

with:

```ruby
index_names
wait
```

Default:

```ruby
wait: false
```

---

# Reversibility

`build_indexes` remains irreversible.

Therefore:

```ruby
def change
  build_indexes :type_company,
                wait: true
end
```

raises:

```ruby
CouchbaseOrm::IrreversibleMigration
```

during rollback.

Complex migrations should use:

```ruby
def up
end

def down
end
```

---

# Example

Safe index replacement:

```ruby
class ChangeFleetByCompanyIndex < CouchbaseOrm::IndexMigration
  def up
    add_index :fleet_by_company_v2,
      keys: [:type, :company_id],
      defer_build: true

    build_indexes :fleet_by_company_v2,
                  wait: true

    remove_index :fleet_by_company
  end

  def down
    add_index :fleet_by_company,
      keys: [:company_id, :type],
      defer_build: true

    build_indexes :fleet_by_company,
                  wait: true

    remove_index :fleet_by_company_v2
  end
end
```

---

# Acceptance Criteria

### Default behavior

Given:

```ruby
build_indexes :type_company
```

Then:

* `BUILD INDEX` is executed;
* no polling is performed.

### Wait behavior

Given:

```ruby
build_indexes :type_company,
              wait: true
```

Then:

* `BUILD INDEX` is executed;
* `system:indexes` is polled;
* execution resumes only when the index becomes `online`.

### Multiple indexes

Given:

```ruby
build_indexes :type_company,
              :date_on_type,
              wait: true
```

Then execution resumes only when both indexes are online.
