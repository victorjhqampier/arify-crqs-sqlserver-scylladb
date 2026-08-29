# POC CQRS con CDC

Flujo objetivo: `SQL Server (CDC) -> Debezium -> Kafka KRaft -> Kafka Connect Sink -> ScyllaDB`.

Cada componente tiene su propio Compose, variables y README. Ningun Compose usa `depends_on`, DNS o `.env` de otro componente.

## Componentes

| Componente | Compose | Contrato externo |
| --- | --- | --- |
| ScyllaDB | `server-sdd/scylladb/` | Expone CQL en `9042`. |
| Kafka | `server-hdd/kafka/` | Expone el broker configurado en `KAFKA_ADVERTISED_HOST:KAFKA_ADVERTISED_PORT`. |
| Kafka Connect Sink | `server-hdd/kafka-connect-sink/` | Worker exclusivo para `Kafka -> ScyllaDB`; REST local `8084`. |
| SQL Server | `server-hdd/sql-server/` | Expone SQL Server en `1433`. |
| Kafka Connect Debezium | `server-hdd/kafka-connect-debezium/` | Worker exclusivo para `SQL Server CDC -> Kafka`; REST local `8083`. |

## Preparacion

```sh
# En 192.168.3.204 (server-sdd)
mv server-sdd/scylladb/.env.example server-sdd/scylladb/.env

# En 192.168.3.219 (server-hdd)
mv server-hdd/kafka/.env.example server-hdd/kafka/.env
mv server-hdd/kafka/topics.env.example server-hdd/kafka/topics.env
mv server-hdd/kafka-connect-sink/.env.example server-hdd/kafka-connect-sink/.env
mv server-hdd/sql-server/.env.example server-hdd/sql-server/.env
mv server-hdd/kafka-connect-debezium/.env.example server-hdd/kafka-connect-debezium/.env
```

Valores clave:

```env
# server-hdd/kafka/.env
KAFKA_ADVERTISED_HOST=192.168.3.219

# server-hdd/kafka-connect-sink/.env
KAFKA_BOOTSTRAP_SERVERS=192.168.3.219:9092
SCYLLA_CONTACT_POINTS=192.168.3.204
SCYLLA_SINK_USERNAME=arify_kafka_sink
SCYLLA_SINK_PASSWORD=<PASSWORD_REAL>

# server-hdd/kafka-connect-debezium/.env
SQLSERVER_HOST=192.168.3.219
KAFKA_BOOTSTRAP_SERVERS=192.168.3.219:9092
SQLSERVER_DB=my_db_transaction
DEBEZIUM_USER=debezium
DEBEZIUM_PASSWORD=<PASSWORD_REAL>
```

## Orden Oficial

El orden evita perder eventos reales por fallas del Sink:

```text
1. ScyllaDB
2. Kafka
3. Kafka Connect Sink
4. Healthcheck Kafka -> ScyllaDB
5. SQL Server + CDC
6. Kafka Connect Debezium
7. Validacion end-to-end real
```

## 1. ScyllaDB

```sh
cd server-sdd/scylladb
sudo mkdir -p /var/apps/scylladb/data
sudo chmod 777 -R /var/apps/scylladb
docker compose up -d --remove-orphans
docker compose ps
until docker logs arify-scylladb 2>&1 | grep -q "initialization completed"; do sleep 5; done
```

Bootstrap inicial con directorio de datos nuevo:

```sh
docker exec -i arify-scylladb cqlsh -u cassandra -p cassandra -e "ALTER ROLE cassandra WITH PASSWORD = 'Sysadmin321++';"
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/00-keyspace.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/10-proyecciones.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/20-healthcheck.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/90-bootstrap-roles.cql
```

Validar healthcheck table y rol Sink:

```sql
DESCRIBE TABLE arify_cqrs.kafka_sink_healthcheck;
SELECT role, can_login, is_superuser FROM system_auth.roles WHERE role = 'arify_kafka_sink';
```

## 2. Kafka

```sh
cd server-hdd/kafka
test -f .env || cp .env.example .env
test -f topics.env || cp topics.env.example topics.env
podman compose up -d --remove-orphans
podman compose ps
podman exec -it arify-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

Crear topicos:

```sh
set -a
. ./topics.env
set +a

podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists --topic "$HEALTHCHECK_TOPIC" \
  --partitions 1 --replication-factor 1 \
  --config retention.ms=300000 --config segment.ms=60000

for topic in "$CDC_TOPIC_KARDEX" "$CDC_TOPIC_AGENCIA" "$CDC_TOPIC_CANAL"; do
  podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic "$topic" \
    --partitions 1 --replication-factor 1 \
    --config retention.ms=300000 --config segment.ms=60000
done

for topic in \
  "$DEBEZIUM_CONNECT_CONFIG_TOPIC" \
  "$DEBEZIUM_CONNECT_OFFSET_TOPIC" \
  "$DEBEZIUM_CONNECT_STATUS_TOPIC" \
  "$SINK_CONNECT_CONFIG_TOPIC" \
  "$SINK_CONNECT_OFFSET_TOPIC" \
  "$SINK_CONNECT_STATUS_TOPIC"; do
  podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic "$topic" \
    --partitions 1 --replication-factor 1 \
    --config cleanup.policy=compact
done

podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists --topic "$SCHEMA_HISTORY_TOPIC" \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=delete \
  --config retention.ms=-1
```

Si `SCHEMA_HISTORY_TOPIC` ya existia como compactado, corregirlo antes de Debezium:

```sh
podman exec -it arify-kafka /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server localhost:9092 \
  --entity-type topics \
  --entity-name "$SCHEMA_HISTORY_TOPIC" \
  --alter \
  --add-config cleanup.policy=delete,retention.ms=-1
```

## 3. Kafka Connect Sink

```sh
cd server-hdd/kafka-connect-sink
test -f .env || cp .env.example .env
nc -vz 192.168.3.219 9092
nc -vz 192.168.3.204 9042
podman compose up -d --remove-orphans
podman compose ps
curl -fsS http://127.0.0.1:8084/connectors
```

Registrar el healthcheck Sink:

```sh
bash register-healthcheck-sink.sh
curl -s http://127.0.0.1:8084/connectors/scylladb-healthcheck-sink/status
```

## 4. Healthcheck Kafka -> ScyllaDB

Con `scylladb-healthcheck-sink` en `RUNNING`, producir un evento manual:

```sh
set -a
. ../kafka/topics.env
set +a

podman exec -i arify-kafka /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic "$HEALTHCHECK_TOPIC" \
  --property parse.key=true \
  --property key.separator='|' <<'EOF'
{"check_id":"sink-healthcheck-001"}|{"source":"manual-kafka-producer","message":"Kafka to ScyllaDB sink is writable","created_at":"2026-08-29T00:00:00Z"}
EOF
```

Validar en ScyllaDB:

```sql
SELECT * FROM arify_cqrs.kafka_sink_healthcheck WHERE check_id = 'sink-healthcheck-001';
```

Solo si la fila aparece, registrar el Sink CDC real:

```sh
bash register-sink.sh
curl -s http://127.0.0.1:8084/connectors/scylladb-sink/status
```

## 5. SQL Server + CDC

```sh
cd server-hdd/sql-server
sudo mkdir -p /var/app/mssql
sudo chmod 777 -R /var/app/mssql
podman compose up -d --remove-orphans
podman compose ps
until podman exec arix-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P 'Sysadmin321++' -Q "SELECT 1" >/dev/null 2>&1; do sleep 5; done
```

Copiar backup, validar logical names y restaurar como `my_db_transaction`:

```sh
scp /Users/vcaxi/Downloads/temp/apibus-trx/To-Be/db_transaction.bak skynet@192.168.3.219:/var/apps/database/mssql/backups/
podman exec -it arix-mssql ls -lh /var/opt/mssql/backups

podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backups/db_transaction.bak';"

podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "RESTORE DATABASE [my_db_transaction]
      FROM DISK = N'/var/opt/mssql/backups/db_transaction.bak'
      WITH
        MOVE N'db_transaction' TO N'/var/opt/mssql/data/my_db_transaction.mdf',
        MOVE N'db_transaction_log' TO N'/var/opt/mssql/data/my_db_transaction_log.ldf',
        REPLACE,
        RECOVERY,
        STATS = 5;"
```

Habilitar CDC:

```sh
podman exec -it arix-mssql /opt/mssql/bin/mssql-conf set sqlagent.enabled true
podman restart arix-mssql
until podman exec arix-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P 'Sysadmin321++' -Q "SELECT 1" >/dev/null 2>&1; do sleep 5; done
podman exec -it arix-mssql /bin/bash /scripts/init-cdc.sh
```

Validar CDC y usuario Debezium:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -Q "SELECT name, is_tracked_by_cdc FROM sys.tables WHERE name IN (N'SI_FinKardex', N'SI_FinAgenciaCCE', N'SI_FinCanalCCE');"

podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U debezium -P 'Sysadmin321++' -d my_db_transaction \
  -Q "SELECT DB_NAME() AS dbname, SUSER_SNAME() AS login_name;"

podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -d my_db_transaction \
  -Q "SELECT TOP (10) __\$start_lsn, __\$operation, idAgenciaCCE, cNombreOficina, lVigente
      FROM cdc.dbo_SI_FinAgenciaCCE_CT
      ORDER BY __\$start_lsn DESC;"
```

## 6. Kafka Connect Debezium

```sh
cd server-hdd/kafka-connect-debezium
test -f .env || cp .env.example .env
nc -vz 192.168.3.219 9092
nc -vz 192.168.3.219 1433
podman compose up -d --remove-orphans
podman compose ps
curl -fsS http://127.0.0.1:8083/connectors
bash register-debezium.sh
curl -s http://127.0.0.1:8083/connectors/debezium-sqlserver/status
```

Confirmar que Debezium publico en Kafka:

```sh
podman exec arify-kafka /opt/kafka/bin/kafka-get-offsets.sh \
  --bootstrap-server localhost:9092 \
  --topic sqlserver.my_db_transaction.dbo.SI_FinAgenciaCCE
```

## 7. Validacion End-To-End

Con `scylladb-sink` y `debezium-sqlserver` en `RUNNING`, haga un `INSERT` o `UPDATE` en SQL Server y valide:

```sh
curl -s http://127.0.0.1:8083/connectors/debezium-sqlserver/status
curl -s http://127.0.0.1:8084/connectors/scylladb-sink/status
podman exec arify-kafka /opt/kafka/bin/kafka-get-offsets.sh \
  --bootstrap-server localhost:9092 \
  --topic sqlserver.my_db_transaction.dbo.SI_FinAgenciaCCE
```

En ScyllaDB:

```sql
SELECT * FROM arify_cqrs.si_fin_agencia_cce LIMIT 10;
```

## Contratos Que Deben Coincidir

- `SQLSERVER_DB`, `DEBEZIUM_USER` y su secreto deben coincidir entre SQL Server y `kafka-connect-debezium`, aunque se almacenen en `.env` distintos.
- Los topicos CDC y `HEALTHCHECK_TOPIC` de `kafka/topics.env` deben coincidir con los `.env` de los workers Connect.
- Los topicos internos exclusivos `arify-debezium-*` y `arify-sink-*` usan compactacion; `arify-schema-history.sqlserver` usa `cleanup.policy=delete` y `retention.ms=-1`.
- `KAFKA_ADVERTISED_HOST:KAFKA_ADVERTISED_PORT` debe ser alcanzable desde ambos workers y coincidir con `KAFKA_BOOTSTRAP_SERVERS`.
- `SCYLLA_LOCAL_DC`, `SCYLLA_SINK_USERNAME` y `SCYLLA_SINK_PASSWORD` deben coincidir entre ScyllaDB y `kafka-connect-sink`.

Los `.env` no se versionan. Consulte el README de cada componente antes de desplegarlo.
