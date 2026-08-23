#!/usr/bin/env bash
# Creates the externally agreed CDC topics without receiving source-system credentials.
set -Eeuo pipefail

create_topic() {
  local topic="$1"
  shift
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --create --if-not-exists \
    --topic "${topic}" --partitions 1 --replication-factor 1 "$@"
}

for topic in "${CDC_TOPIC_KARDEX}" "${CDC_TOPIC_AGENCIA}" "${CDC_TOPIC_CANAL}"; do
  create_topic "${topic}" --config retention.ms=300000 --config segment.ms=60000

for topic in "${CONNECT_CONFIG_TOPIC}" "${CONNECT_OFFSET_TOPIC}" "${CONNECT_STATUS_TOPIC}" "${SCHEMA_HISTORY_TOPIC}"; do
  create_topic "${topic}" --config cleanup.policy=compact
