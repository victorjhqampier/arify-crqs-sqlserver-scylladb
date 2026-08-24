#!/usr/bin/env bash
# Registers only the Debezium source in this dedicated Kafka Connect worker.
set -Eeuo pipefail

component_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
env_file="${component_dir}/.env"

if [[ ! -f "${env_file}" ]]; then
  printf 'Missing %s. Copy .env.example and configure this component first.\n' "${env_file}" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "${env_file}"
set +a

curl --fail --show-error --silent \
  --request PUT \
  --header 'Content-Type: application/json' \
  --data-binary "@${component_dir}/connectors/debezium-sqlserver.json" \
  "${KAFKA_CONNECT_URL}/connectors/debezium-sqlserver/config"
printf '\nRegistered debezium-sqlserver\n'
