# Spec: Index Migration Configuration for Rails Railtie

## Motivation

The existing Railtie already loads connection settings from `config/couchbase.yml` using:

```ruby
CouchbaseOrm::Connection.config = Rails.application.config_for(:couchbase)
```

Index migration settings should follow the same approach so that Rails users can configure everything in a single file.

Today, index migration settings are only configurable through Ruby:

```ruby
CouchbaseOrm.configure do |config|
  config.index.bucket = "fleet-prod"
  config.index.num_replica = 1
  config.index.migrations_path = "db/indexes"
end
```

This feature allows index settings to be configured from `config/couchbase.yml` while preserving existing behavior.

---

# Goals

* Configure index migration settings from `config/couchbase.yml`.
* Reuse the same configuration loading mechanism as connection settings.
* Preserve default values when index settings are absent.
* Reuse the connection bucket by default.
* Preserve existing non-Rails behavior.
* Allow runtime overrides through `CouchbaseOrm.configure`.

---

# Non-Goals

* Introducing additional index migration settings.
* Running index migrations automatically during Rails boot.
* Replacing the existing `CouchbaseOrm.configure` API.

---

# YAML Configuration

Index migration settings are nested under `index`.

Example:

```yaml
common: &common
  connection_string: couchbase://localhost
  username: dev_user
  password: dev_password

development:
  <<: *common
  bucket: fleet-dev

  index:
    migrations_path: db/indexes
    num_replica: 0

production:
  connection_string: <%= ENV['COUCHBASE_CONNECTION_STRING'] %>
  bucket: <%= ENV['COUCHBASE_BUCKET'] %>
  username: <%= ENV['COUCHBASE_USER'] %>
  password: <%= ENV['COUCHBASE_PASSWORD'] %>

  index:
    bucket: <%= ENV['COUCHBASE_INDEX_BUCKET'] %>
    num_replica: 1
```

---

# Railtie Changes

## Existing initializer

The existing initializer remains unchanged:

```ruby
initializer 'couchbase_orm.setup_connection_config' do
  CouchbaseOrm::Connection.config = Rails.application.config_for(:couchbase)
end
```

## New initializer

A new initializer is added after connection configuration:

```ruby
initializer 'couchbase_orm.setup_index_config',
            after: 'couchbase_orm.setup_connection_config' do
  config_hash = Rails.application.config_for(:couchbase).with_indifferent_access
  index_hash = (config_hash[:index] || {}).with_indifferent_access

  index_config = {
    bucket: config_hash[:bucket]
  }.merge(
    index_hash.slice(
      :bucket,
      :migrations_path,
      :num_replica
    )
  )

  index_config.each do |key, value|
    CouchbaseOrm.config.index.public_send("#{key}=", value)
  end
end
```

Only keys present in the YAML configuration are applied.

Unknown keys are ignored.

---

# Defaults

Defaults from `CouchbaseOrm::Configuration::Index` are preserved.

| Setting         | Default        |
| --------------- | -------------- |
| migrations_path | `"db/indexes"` |
| bucket          | `nil`          |
| num_replica     | `0`            |

---

# Bucket Resolution

By default, index migrations use the same bucket as the connection configuration.

Example:

```yaml
development:
  bucket: fleet-dev
```

results in:

```ruby
CouchbaseOrm.config.index.bucket
# => "fleet-dev"
```

The bucket may be overridden explicitly:

```yaml
development:
  bucket: fleet-dev

  index:
    bucket: fleet-indexes
```

resulting in:

```ruby
CouchbaseOrm.config.index.bucket
# => "fleet-indexes"
```

---

# Behavior

## Configuration Source

Connection settings and index migration settings are both loaded from:

```ruby
Rails.application.config_for(:couchbase)
```

using the environment-specific entry in `config/couchbase.yml`.

---

## Precedence

Configuration values are applied in the following order:

1. Defaults from `CouchbaseOrm::Configuration::Index`.
2. Connection bucket from `config/couchbase.yml`.
3. Values from the nested `index` section.
4. Any later explicit `CouchbaseOrm.configure` call.

This preserves the ability to override configuration at runtime.

---

# Acceptance Criteria

1. When `index.migrations_path` is defined in `config/couchbase.yml`,
   `CouchbaseOrm.config.index.migrations_path` matches the configured value.

2. When `index.num_replica` is defined,
   `CouchbaseOrm.config.index.num_replica` matches the configured value.

3. When `index.bucket` is absent,
   `CouchbaseOrm.config.index.bucket` equals the connection bucket.

4. When `index.bucket` is present,
   it overrides the connection bucket.

5. When the `index` section is absent,
   defaults remain unchanged except that the index bucket defaults to the connection bucket.

6. The `couchbase_orm.setup_index_config` initializer runs after
   `couchbase_orm.setup_connection_config`.

7. Existing non-Rails usage through `CouchbaseOrm.configure` remains unchanged.

8. Explicit calls to `CouchbaseOrm.configure` made after Rails initialization override values loaded from YAML.

9. Unknown keys under `index` are ignored.
