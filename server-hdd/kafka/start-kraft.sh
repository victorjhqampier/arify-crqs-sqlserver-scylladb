#!/usr/bin/env bash
# Formats a new KRaft volume once; --ignore-formatted preserves existing cluster metadata.
set -Eeuo pipefail

: "${KAFKA_CLUSTER_ID:?Set KAFKA_CLUSTER_ID in kafka/.env}"
: "${KAFKA_ADVERTISED_HOST:?Set KAFKA_ADVERTISED_HOST in kafka/.env}"
: "${KAFKA_ADVERTISED_PORT:?Set KAFKA_ADVERTISED_PORT in kafka/.env}"

config=/tmp/server.properties
sed \
  -e "s|__KAFKA_ADVERTISED_HOST__|${KAFKA_ADVERTISED_HOST}|g" \
  -e "s|__KAFKA_ADVERTISED_PORT__|${KAFKA_ADVERTISED_PORT}|g" \
  /etc/kafka/server.properties > "${config}"

/opt/kafka/bin/kafka-storage.sh format \
  --ignore-formatted \
  --cluster-id "${KAFKA_CLUSTER_ID}" \
  --config "${config}"

exec /opt/kafka/bin/kafka-server-start.sh "${config}"
