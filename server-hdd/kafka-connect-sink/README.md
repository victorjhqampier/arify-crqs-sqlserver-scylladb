# Kafka Connect Sink

This component is a Kafka Connect worker dedicated only to the DataStax Cassandra Sink plugin. It is responsible for `Kafka -> ScyllaDB`; it does not contain or register Debezium.

## Configuration

```sh
test -f .env || cp .env.example .env
```

Set Kafka, ScyllaDB, topic names, and the Sink role secret in `.env`. Its internal Connect topics must remain `arify-sink-*` and must not be shared with another Kafka Connect worker. `HEALTHCHECK_TOPIC` must match `server-hdd/kafka/topics.env`.

## Start and validate

Start this component after the ScyllaDB keyspace, tables, Sink role, Kafka internal topics, and `HEALTHCHECK_TOPIC` exist:

```sh
podman compose up -d --remove-orphans
podman compose ps
curl -fsS http://127.0.0.1:8084/connectors
curl -fsS http://127.0.0.1:8084/connector-plugins
```

Validate Kafka -> ScyllaDB first with the healthcheck connector:

```sh
set -a
. ./.env
set +a

bash register-healthcheck-sink.sh
curl -s http://127.0.0.1:8084/connectors/scylladb-healthcheck-sink/status
podman exec -i arify-kafka /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic "$HEALTHCHECK_TOPIC" \
  --property parse.key=true \
  --property key.separator='|' <<'EOF'
{"check_id":"sink-healthcheck-001"}|{"source":"manual-kafka-producer","message":"Kafka to ScyllaDB sink is writable","created_at":"2026-08-29T00:00:00Z"}
EOF
```

Validate in ScyllaDB:

```sql
SELECT * FROM arify_cqrs.kafka_sink_healthcheck WHERE check_id = 'sink-healthcheck-001';
```

Register the CDC Sink only after the healthcheck row is visible:

```sh
bash register-sink.sh
curl -s http://127.0.0.1:8084/connectors/scylladb-sink/status
```

The task must be `RUNNING` before relying on CDC records. Then verify rows in ScyllaDB; do not use a Kafka message produced before this connector was registered as the acceptance test.
