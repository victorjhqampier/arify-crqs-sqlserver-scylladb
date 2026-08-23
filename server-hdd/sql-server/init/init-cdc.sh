#!/usr/bin/env bash
# Enables CDC on pre-existing source tables only after SQL Server is healthy.
set -Eeuo pipefail

sqlcmd=(/opt/mssql-tools18/bin/sqlcmd -C -S sql-server -U sa -P "${SA_PASSWORD}")
variables=(
  "DB_NAME=${SQLSERVER_DB}"
  "DEBEZIUM_USER=${DEBEZIUM_USER}"
  "DEBEZIUM_PASSWORD=${DEBEZIUM_PASSWORD}"
)

"${sqlcmd[@]}" -i /scripts/10-enable-cdc.sql -v "${variables[@]}"
