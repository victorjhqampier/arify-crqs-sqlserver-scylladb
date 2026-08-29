-- Minimal table used to validate Kafka -> DataStax Sink -> ScyllaDB before SQL Server/Debezium.

CREATE TABLE IF NOT EXISTS arify_cqrs.kafka_sink_healthcheck (
    check_id text PRIMARY KEY,
    source text,
    message text,
    created_at timestamp
);
