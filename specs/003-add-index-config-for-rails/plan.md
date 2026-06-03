# Implementation Plan: Rails Index Migration Configuration

## Goal

Allow Rails applications to configure index migration settings from
`config/couchbase.yml`, using the same loading model as connection settings.

The index bucket should default to the connection bucket unless explicitly overridden.

---

# Phase 1 — Configuration Merge

## Goal

Define the final configuration precedence.

### Precedence

1. Defaults from `CouchbaseOrm::Configuration::Index`.
2. Connection bucket from `config/couchbase.yml`.
3. Nested `index` section values.
4. Later explicit `CouchbaseOrm.configure` calls.

Example:

```yaml
development:
  bucket: fleet-dev

  index:
    num_replica: 1
```

Result:

```ruby
CouchbaseOrm.config.index.bucket
# => "fleet-dev"

CouchbaseOrm.config.index.num_replica
# => 1
```

---

# Phase 2 — Add Railtie Initializer

## Goal

Load index configuration after connection configuration.

Current:

```ruby
initializer 'couchbase_orm.setup_connection_config' do
  CouchbaseOrm::Connection.config = Rails.application.config_for(:couchbase)
end
```

Add:

```ruby
initializer 'couchbase_orm.setup_index_config',
            after: 'couchbase_orm.setup_connection_config'
```

This guarantees connection configuration is already available.

---

# Phase 3 — Load YAML Configuration

## Goal

Reuse the same configuration source.

Load:

```ruby
config_hash =
  Rails.application
       .config_for(:couchbase)
       .with_indifferent_access
```

Extract:

```ruby
index_hash =
  (config_hash[:index] || {})
    .with_indifferent_access
```

---

# Phase 4 — Merge Connection Bucket

## Goal

Default index bucket to the application bucket.

Build:

```ruby
index_config = {
  bucket: config_hash[:bucket]
}.merge(
  index_hash.slice(
    :bucket,
    :migrations_path,
    :num_replica
  )
)
```

Behavior:

Connection bucket:

```yaml
bucket: fleet-prod
```

becomes:

```ruby
CouchbaseOrm.config.index.bucket
# => "fleet-prod"
```

unless:

```yaml
index:
  bucket: fleet-indexes
```

is present.

---

# Phase 5 — Apply Configuration

## Goal

Populate `CouchbaseOrm.config.index`.

For each value:

```ruby
index_config.each do |key, value|
  CouchbaseOrm.config.index.public_send("#{key}=", value)
end
```

Only keys present in the merged configuration are applied.

Unknown YAML keys are ignored.

---

# Phase 6 — Preserve Defaults

## Goal

Allow defaults to remain when values are absent.

Defaults:

```ruby
migrations_path = "db/indexes"
bucket = nil
num_replica = 0
```

Example:

```yaml
development:
  bucket: fleet-dev
```

Result:

```ruby
bucket = "fleet-dev"
migrations_path = "db/indexes"
num_replica = 0
```

---

# Phase 7 — Tests

## Loads migrations_path

Given:

```yaml
index:
  migrations_path: custom/indexes
```

Expect:

```ruby
CouchbaseOrm.config.index.migrations_path
# => "custom/indexes"
```

---

## Loads num_replica

Given:

```yaml
index:
  num_replica: 1
```

Expect:

```ruby
CouchbaseOrm.config.index.num_replica
# => 1
```

---

## Defaults bucket to connection bucket

Given:

```yaml
bucket: fleet-dev
```

Expect:

```ruby
CouchbaseOrm.config.index.bucket
# => "fleet-dev"
```

---

## Allows explicit index bucket override

Given:

```yaml
bucket: fleet-dev

index:
  bucket: fleet-indexes
```

Expect:

```ruby
CouchbaseOrm.config.index.bucket
# => "fleet-indexes"
```

---

## Preserves defaults

Given:

```yaml
bucket: fleet-dev
```

Expect:

```ruby
CouchbaseOrm.config.index.migrations_path
# => "db/indexes"

CouchbaseOrm.config.index.num_replica
# => 0
```

---

## Ignores unknown keys

Given:

```yaml
index:
  foo: bar
```

Expect:

```ruby
CouchbaseOrm.config.index.respond_to?(:foo)
# => false
```

and no exception is raised.

---

## Supports runtime override

After Rails initialization:

```ruby
CouchbaseOrm.configure do |config|
  config.index.num_replica = 2
end
```

Expect:

```ruby
CouchbaseOrm.config.index.num_replica
# => 2
```

---

# V1 Complete

Supported:

* `migrations_path`
* `bucket`
* `num_replica`
* bucket inheritance from connection configuration
* explicit bucket override
* runtime override via `CouchbaseOrm.configure`

Not supported:

* automatic migration execution
* additional index settings
* non-Rails configuration changes
* validation of unknown keys
* environment-specific runtime reload
