# Kafka Connect Debezium

This component is a Kafka Connect worker dedicated only to the Debezium SQL Server Source plugin. It is responsible for `SQL Server CDC -> Kafka`; it does not contain or register a ScyllaDB Sink.

## Configuration

```sh
test -f .env || cp .env.example .env
```

Set the SQL Server and Kafka endpoints in `.env`. Its internal Connect topics must remain `arify-debezium-*` and must not be shared with another Kafka Connect worker.

## Start and validate

```sh
podman compose up -d --remove-orphans
podman compose ps
curl -fsS http://127.0.0.1:8083/connectors
curl -fsS http://127.0.0.1:8083/connector-plugins
```

Register only Debezium:

```sh
bash register-debezium.sh
curl -s http://127.0.0.1:8083/connectors/debezium-sqlserver/status
```

Acceptance criterion: after the initial snapshot or a committed `INSERT`/`UPDATE`, the matching CDC Kafka topic must have an offset greater than `0`. Do not start the Sink validation until this is true.
