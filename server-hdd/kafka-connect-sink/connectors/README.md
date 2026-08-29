# ScyllaDB Sink Connector

`scylladb-sink.json.template` is rendered and registered only through `../register-sink.sh` against this worker's REST API on port `8084`. `scylladb-healthcheck-sink.json.template` is rendered and registered through `../register-healthcheck-sink.sh` to validate `Kafka -> ScyllaDB` before CDC.

The template maps each fixed Debezium topic to its ScyllaDB projection table. Runtime endpoints and credentials are resolved from this component's non-versioned `.env` through the Kafka Connect `env` config provider.

SQL Server is the source of truth for fields on the right side of each mapping, for example `value.dFecHoraOpe`. The left side is the physical CQL column, which ScyllaDB normalizes to lowercase when the DDL identifier is unquoted, for example `dfechoraope=value.dFecHoraOpe`.
