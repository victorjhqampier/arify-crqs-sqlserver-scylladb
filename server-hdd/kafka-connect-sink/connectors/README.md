# ScyllaDB Sink Connector

`scylladb-sink.json.template` is rendered and registered only through `../register-sink.sh` against this worker's REST API on port `8084`.

The template maps each fixed Debezium topic to its ScyllaDB projection table. Runtime endpoints and credentials are resolved from this component's non-versioned `.env` through the Kafka Connect `env` config provider.
