#!/usr/bin/env bash
# Renders topic/keyspace names and registers only the ScyllaDB Sink connector.
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

escape_sed() {
  printf '%s' "$1" | sed 's/[\\&|]/\\&/g'
}

rendered_sink="$(mktemp)"
trap 'rm -f "${rendered_sink}"' EXIT
sed \
  -e "s|__CDC_TOPIC_KARDEX__|$(escape_sed "${CDC_TOPIC_KARDEX}")|g" \
  -e "s|__CDC_TOPIC_AGENCIA__|$(escape_sed "${CDC_TOPIC_AGENCIA}")|g" \
  -e "s|__CDC_TOPIC_CANAL__|$(escape_sed "${CDC_TOPIC_CANAL}")|g" \
  -e "s|__SCYLLA_KEYSPACE__|$(escape_sed "${SCYLLA_KEYSPACE}")|g" \
  "${component_dir}/connectors/scylladb-sink.json.template" > "${rendered_sink}"

curl --fail --show-error --silent \
  --request PUT \
  --header 'Content-Type: application/json' \
  --data-binary "@${rendered_sink}" \
  "${KAFKA_CONNECT_URL}/connectors/scylladb-sink/config"
printf '\nRegistered scylladb-sink\n'
