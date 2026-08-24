# Kafka Connect Sink

This component is a Kafka Connect worker dedicated only to the DataStax Cassandra Sink plugin. It is responsible for `Kafka CDC topics -> ScyllaDB`; it does not contain or register Debezium.

## Configuration

```sh
test -f .env || cp .env.example .env
```

Set Kafka, ScyllaDB, topic names, and the Sink role secret in `.env`. Its internal Connect topics must remain `arify-sink-*` and must not be shared with another Kafka Connect worker.

## Start and validate

Start this component only after the ScyllaDB keyspace, tables, role, and CDC topics exist:

```sh
podman compose up -d --remove-orphans
podman compose ps
curl -fsS http://127.0.0.1:8084/connectors
curl -fsS http://127.0.0.1:8084/connector-plugins
bash register-sink.sh
curl -s http://127.0.0.1:8084/connectors/scylladb-sink/status
```

The task must be `RUNNING` before producing a new manual test record. Then verify the row in ScyllaDB and the Sink consumer-group lag; do not use a Kafka message produced before this connector was registered as the acceptance test.
