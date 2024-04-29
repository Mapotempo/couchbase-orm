#!/bin/sh

set -x
set -e

curl -u Administrator:password -X POST "${COUCHBASE_HOST}:8091/node/controller/setupServices" \
    -d 'services=kv%2Cn1ql%2Cindex'

curl -u Administrator:password -X POST "${COUCHBASE_HOST}:8091/pools/default" \
    -d memoryQuota=320 \
    -d indexMemoryQuota=256

curl -u Administrator:password -X POST "${COUCHBASE_HOST}:8091/settings/web" \
    -d password=password \
    -d username=admin \
    -d port=8091

curl -u "admin:password" -X POST "${COUCHBASE_HOST}:8091/settings/indexes" \
    -d 'storageMode=plasma'

curl -u "admin:password" -X POST "${COUCHBASE_HOST}:8091/pools/default/buckets" \
    -d flushEnabled=1 \
    -d replicaNumber=0 \
    -d evictionPolicy=fullEviction \
    -d ramQuotaMB=160 \
    -d bucketType=couchbase \
    -d name="${COUCHBASE_BUCKET}"

sleep 1

curl -u admin:password -X PUT http://${COUCHBASE_HOST}:8091/settings/rbac/users/local/${COUCHBASE_USER} \
  -d password=${COUCHBASE_PASSWORD} \
  -d roles=admin

sleep 5

curl "http://admin:password@${COUCHBASE_HOST}:8093/query/service" -d "statement=CREATE INDEX \`default_type\` ON \`$COUCHBASE_BUCKET\`(\`type\`)"
curl "http://admin:password@${COUCHBASE_HOST}:8093/query/service" -d "statement=CREATE INDEX \`default_rating\` ON \`$COUCHBASE_BUCKET\`(\`rating\`)"
curl "http://admin:password@${COUCHBASE_HOST}:8093/query/service" -d "statement=CREATE INDEX \`default_name\` ON \`$COUCHBASE_BUCKET\`(\`name\`)"