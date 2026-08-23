#!/usr/bin/env bash
# Runs manually inside the SQL Server container to enable CDC on pre-existing source tables.
set -Eeuo pipefail

sqlcmd=(/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "${SA_PASSWORD}")
variables=(
  "DB_NAME=${SQLSERVER_DB}"
  "DEBEZIUM_USER=${DEBEZIUM_USER}"
  "DEBEZIUM_PASSWORD=${DEBEZIUM_PASSWORD}"
)

"${sqlcmd[@]}" -i /scripts/10-enable-cdc.sql -v "${variables[@]}"
