#!/usr/bin/env bash
# Bootstraps authenticated CQL access, applies schemas, and grants least-privilege service roles.
set -Eeuo pipefail

: "${SCYLLA_SUPERUSER_PASSWORD:?Set SCYLLA_SUPERUSER_PASSWORD in scylladb/.env}"
: "${SCYLLA_SINK_USERNAME:?Set SCYLLA_SINK_USERNAME in scylladb/.env}"
: "${SCYLLA_SINK_PASSWORD:?Set SCYLLA_SINK_PASSWORD in scylladb/.env}"
: "${SCYLLA_READONLY_USERNAME:?Set SCYLLA_READONLY_USERNAME in scylladb/.env}"
: "${SCYLLA_READONLY_PASSWORD:?Set SCYLLA_READONLY_PASSWORD in scylladb/.env}"

validate_role() {
  [[ "$1" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || {
    printf 'Invalid CQL role name: %s\n' "$1" >&2
    exit 1
  }
}

cql_string() {
  printf '%s' "$1" | sed "s/'/''/g"
}

for role in "${SCYLLA_SINK_USERNAME}" "${SCYLLA_READONLY_USERNAME}"; do
  validate_role "${role}"
done

superuser=cassandra
if cqlsh scylladb -u "${superuser}" -p "${SCYLLA_SUPERUSER_PASSWORD}" -e 'DESCRIBE KEYSPACES' >/dev/null 2>&1; then
  : # The configured password is already active.
elif cqlsh scylladb -u "${superuser}" -p cassandra -e 'DESCRIBE KEYSPACES' >/dev/null 2>&1; then
  cqlsh scylladb -u "${superuser}" -p cassandra -e \
    "ALTER ROLE ${superuser} WITH PASSWORD = '$(cql_string "${SCYLLA_SUPERUSER_PASSWORD}")' AND LOGIN = true AND SUPERUSER = true;"
else
  printf 'Cannot authenticate the ScyllaDB superuser with the configured or bootstrap password.\n' >&2
  exit 1
fi

cql() {
  cqlsh scylladb -u "${superuser}" -p "${SCYLLA_SUPERUSER_PASSWORD}" "$@"
}

for file in /cql/*.cql; do
  cql -f "${file}"
done

cql -e "CREATE ROLE IF NOT EXISTS ${SCYLLA_SINK_USERNAME} WITH PASSWORD = '$(cql_string "${SCYLLA_SINK_PASSWORD}")' AND LOGIN = true AND SUPERUSER = false;"
cql -e "ALTER ROLE ${SCYLLA_SINK_USERNAME} WITH PASSWORD = '$(cql_string "${SCYLLA_SINK_PASSWORD}")' AND LOGIN = true AND SUPERUSER = false;"
cql -e "GRANT MODIFY ON KEYSPACE arify_cqrs TO ${SCYLLA_SINK_USERNAME};"

cql -e "CREATE ROLE IF NOT EXISTS ${SCYLLA_READONLY_USERNAME} WITH PASSWORD = '$(cql_string "${SCYLLA_READONLY_PASSWORD}")' AND LOGIN = true AND SUPERUSER = false;"
cql -e "ALTER ROLE ${SCYLLA_READONLY_USERNAME} WITH PASSWORD = '$(cql_string "${SCYLLA_READONLY_PASSWORD}")' AND LOGIN = true AND SUPERUSER = false;"
cql -e "GRANT SELECT ON KEYSPACE arify_cqrs TO ${SCYLLA_READONLY_USERNAME};"
