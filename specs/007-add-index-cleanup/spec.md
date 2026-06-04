# Spec: Add Index Cleanup Command

## Motivation

In development and test environments, index state can drift from migration files.

Common situations:

* manually created indexes;
* stale indexes from previous experiments;
* failed migration attempts leaving partial state.

Current commands support migrate, rollback, dump, and adopt, but there is no single command to reset all secondary indexes in one step.

CouchbaseORM should provide an explicit cleanup command to delete all non-primary indexes from the configured bucket.

---

# Goals

* Add a CLI command in bin/couchbaseorm to remove all non-primary indexes.
* Keep primary index untouched.
* Operate only on the configured bucket.
* Reuse existing query/introspection building blocks.
* Provide deterministic output for automation scripts.

---

# Non-Goals

* Removing primary indexes.
* Creating or rebuilding indexes.
* Comparing with migrations or schema files.
* Automatic confirmation prompts.

---

# Command

Introduce:

```bash
bundle exec couchbaseorm index:cleanup
```

Update usage output in:

```text
bin/couchbaseorm
```

to include:

```text
couchbaseorm index:cleanup
```

---

# Behavior

`index:cleanup` performs:

1. Introspect indexes from `system:indexes` for the configured bucket.
2. Ignore primary indexes.
3. Drop each remaining index.
4. Return/print cleaned index names in sorted order.

If no secondary indexes are found, the command is a no-op and returns an empty result.

---

# Internal API

Introduce:

```ruby
CouchbaseOrm::IndexMigrator.cleanup
```

and instance method:

```ruby
IndexMigrator#cleanup
```

Implementation outline:

```ruby
introspected = CouchbaseOrm::IndexMigration::IndexIntrospector.new.indexes
names = introspected.map { |row| row[:name] }.sort

names.each do |name|
	migration = CouchbaseOrm::IndexMigration.new
	migration.remove_index(name)
end

names
```

Notes:

* `IndexIntrospector` already filters out primary indexes.
* `remove_index` uses the existing query builder and execution path.

---

# CLI Output

When indexes are removed:

```text
Removed indexes:
date_on_type
type_company
```

When there is nothing to remove:

```text
No secondary indexes found
```

---

# Error Handling

* If index bucket configuration is missing, raise the existing bucket configuration error.
* If dropping one index fails, propagate the exception and stop execution.

This keeps behavior consistent with other index commands.

---

# Tests

Add coverage for:

* `IndexMigrator.cleanup` delegates to instance cleanup.
* cleanup drops all introspected non-primary indexes.
* cleanup returns sorted deleted names.
* cleanup returns empty array when no indexes are found.
* CLI command `index:cleanup` triggers cleanup and prints expected output.
* CLI usage text includes `index:cleanup`.
