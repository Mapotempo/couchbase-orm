# Implementation Plan: Wait Support for `build_indexes`

## Phase 1 — Extend BuildIndexes Operation

Add:

```ruby
wait
```

to:

```ruby
CouchbaseOrm::IndexMigration::Operations::BuildIndexes
```

Default:

```ruby
wait = false
```

---

## Phase 2 — Extend Migration DSL

Support:

```ruby
build_indexes(
  :type_company,
  :date_on_type,
  wait: true
)
```

Examples:

```ruby
build_indexes :type_company
```

↓

```ruby
BuildIndexes.new(
  [:type_company],
  wait: false
)
```

```ruby
build_indexes :type_company,
              wait: true
```

↓

```ruby
BuildIndexes.new(
  [:type_company],
  wait: true
)
```

---

## Phase 3 — Preserve Existing BUILD INDEX Behavior

Continue generating:

```sql
BUILD INDEX ON `bucket`
(
  `type_company`,
  `date_on_type`
);
```

When:

```ruby
wait == false
```

execution finishes immediately.

---

## Phase 4 — Add Wait Logic

When:

```ruby
wait == true
```

after executing:

```sql
BUILD INDEX ...
```

poll:

```sql
SELECT name, state
FROM system:indexes
WHERE keyspace_id = $bucket
AND name IN $index_names
```

until every index satisfies:

```ruby
state == "online"
```

---

## Phase 5 — Introduce IndexStateFetcher

Create:

```ruby
CouchbaseOrm::IndexMigration::IndexStateFetcher
```

Responsibilities:

```ruby
states(bucket, index_names)
online?(bucket, index_names)
```

Encapsulate the query:

```sql
SELECT name, state
FROM system:indexes
WHERE keyspace_id = $bucket
AND name IN $index_names
```

---

## Phase 6 — Polling Strategy

Use:

```ruby
sleep(1)
```

Pseudo-code:

```ruby
loop do
  states = fetch_index_states

  break if states.all? { |state| state == "online" }

  sleep(1)
end
```

No timeout is introduced.

---

## Phase 7 — Preserve Rollback Semantics

Rollback of:

```ruby
def change
  build_indexes :type_company,
                wait: true
end
```

continues to raise:

```ruby
CouchbaseOrm::IrreversibleMigration
```

---

## Phase 8 — Tests

### Default

Given:

```ruby
build_indexes :type_company
```

Expect:

```ruby
operation.wait
# => false
```

and no polling.

### Explicit wait

Given:

```ruby
build_indexes :type_company,
              wait: true
```

Expect:

```ruby
operation.wait
# => true
```

and polling until:

```ruby
state == "online"
```

### Multiple indexes

Given:

```ruby
build_indexes :type_company,
              :date_on_type,
              wait: true
```

Expect execution to resume only when both indexes are online.

---

# V1 Complete

Supported:

* `build_indexes(*names)`
* `build_indexes(*names, wait: true)`
* polling `system:indexes`
* multiple indexes

Not supported:

* configurable timeout
* configurable polling interval
* progress reporting
* scope/collection support
* standalone `wait_for_indexes`
* retry mechanisms
