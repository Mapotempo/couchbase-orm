# Implementation Plan: Add Index Cleanup Command

## Goal

Add a CLI command to remove all secondary indexes from the configured bucket:

```bash
bundle exec couchbaseorm index:cleanup
```

The command must:

* delete all non-primary indexes;
* keep primary index untouched;
* operate only on the configured bucket;
* return deterministic output for scripting.

---

## Phase 1 — Add Cleanup API to IndexMigrator

Add class method:

```ruby
CouchbaseOrm::IndexMigrator.cleanup
```

and instance method:

```ruby
IndexMigrator#cleanup
```

`cleanup` should:

1. introspect indexes through `IndexIntrospector`;
2. extract index names;
3. sort names;
4. drop each index;
5. return the sorted names.

---

## Phase 2 — Reuse Existing Remove Path

Implement dropping through existing migration execution flow, not ad-hoc queries.

Expected behavior:

```ruby
migration = CouchbaseOrm::IndexMigration.new
migration.remove_index(index_name)
```

This keeps SQL generation and execution consistent with other operations.

---

## Phase 3 — Add CLI Command in bin/couchbaseorm

Update usage output to include:

```text
couchbaseorm index:cleanup
```

Add command branch:

```ruby
when 'index:cleanup'
  removed = CouchbaseOrm::IndexMigrator.cleanup
```

Output:

* if any removed:

```text
Removed indexes:
<name1>
<name2>
```

* if none:

```text
No secondary indexes found
```

---

## Phase 4 — Error Behavior

Preserve existing errors:

* missing bucket config raises the same configuration error from introspection/query builder;
* failures while dropping an index are not swallowed.

No retries or partial-failure handling in v1.

---

## Phase 5 — Unit Tests for Migrator

Add tests for:

* `IndexMigrator.cleanup` delegates to instance method;
* cleanup drops all introspected indexes;
* cleanup returns sorted index names;
* cleanup returns `[]` when there are no secondary indexes.

Use doubles for introspector and migration execution where practical.

---

## Phase 6 — CLI Tests

Add tests for `bin/couchbaseorm` behavior:

* `index:cleanup` calls `CouchbaseOrm::IndexMigrator.cleanup`;
* command prints removed index names when present;
* command prints `No secondary indexes found` when empty;
* usage text includes `index:cleanup`.

---

## V1 Complete

Supported:

* cleanup command for all secondary indexes in configured bucket;
* deterministic deletion order;
* clear CLI output for non-empty and empty cases.

Not supported:

* dry-run mode;
* confirmation prompt;
* selective cleanup filters.
