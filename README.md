# POC CQRS con CDC

Flujo: `SQL Server (CDC) -> Debezium -> Kafka KRaft -> Kafka Connect Sink -> ScyllaDB`.

Cada componente tiene su propio Compose, variables, red Docker y README. Puede vivir en otro servidor o repositorio. Ningun Compose usa `depends_on`, DNS o archivos `.env` de otro componente.

## Componentes

| Componente | Compose | Contrato externo |
| --- | --- | --- |
| SQL Server | `server-hdd/sql-server/` | Expone SQL Server en `1433`. |
| Kafka | `server-hdd/kafka/` | Expone el broker configurado en `KAFKA_ADVERTISED_HOST:KAFKA_ADVERTISED_PORT`. |
| Kafka Connect Debezium | `server-hdd/kafka-connect-debezium/` | Worker exclusivo para `SQL Server CDC -> Kafka`; REST local `8083`. |
| Kafka Connect Sink | `server-hdd/kafka-connect-sink/` | Worker exclusivo para `Kafka -> ScyllaDB`; REST local `8084`. |
| ScyllaDB | `server-sdd/scylladb/` | Expone CQL en `9042`. |

## Preparacion

En cada servidor, renombre los archivos de configuracion una sola vez. Luego edite los valores reales antes de levantar los servicios.

```sh
# En 192.168.3.204 (server-sdd)
mv server-sdd/scylladb/.env.example server-sdd/scylladb/.env

# En 192.168.3.219 (server-hdd)
mv server-hdd/sql-server/.env.example server-hdd/sql-server/.env
mv server-hdd/kafka/.env.example server-hdd/kafka/.env
mv server-hdd/kafka/topics.env.example server-hdd/kafka/topics.env
mv server-hdd/kafka-connect-debezium/.env.example server-hdd/kafka-connect-debezium/.env
mv server-hdd/kafka-connect-sink/.env.example server-hdd/kafka-connect-sink/.env
```

Configure estas IPs antes del arranque:

```env
# server-hdd/kafka/.env
KAFKA_ADVERTISED_HOST=192.168.3.219

# server-hdd/kafka-connect-debezium/.env
SQLSERVER_HOST=192.168.3.219
KAFKA_BOOTSTRAP_SERVERS=192.168.3.219:9092

# server-hdd/kafka-connect-sink/.env
KAFKA_BOOTSTRAP_SERVERS=192.168.3.219:9092
SCYLLA_CONTACT_POINTS=192.168.3.204
```

## Orden de ejecucion

### 1. ScyllaDB en server-sdd (Docker, 192.168.3.204)

```sh
# Create volumen
sudo mkdir -p /var/apps/scylladb/data
sudo chmod 777 -R /var/apps/scylladb

# Up docker compose
cd server-sdd/scylladb
docker compose up -d --remove-orphans
docker compose ps
until docker logs arify-scylladb 2>&1 | grep -q "initialization completed"; do sleep 5; done

# Solo en el primer bootstrap, despues de crear un directorio de datos nuevo:
docker exec -i arify-scylladb cqlsh -u cassandra -p cassandra -e "ALTER ROLE cassandra WITH PASSWORD = 'Sysadmin321++';"
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/00-keyspace.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/10-proyecciones.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/90-bootstrap-roles.cql
docker exec -it arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++'

# Destroy container
docker compose down
```

Para reiniciar la POC desde cero, ejecute antes de este bloque: `docker compose down`, `sudo rm -rf /var/apps/scylladb/data`, vuelva a crear la ruta y levante con `docker compose up -d --force-recreate --remove-orphans`. El borrado de datos elimina keyspaces, tablas y roles.

En arranques posteriores con los datos existentes, omita el bootstrap y valide directamente con `cassandra/Sysadmin321++`. Continue solo cuando ScyllaDB este `Up`, el cambio de contraseña haya terminado y los tres scripts CQL se hayan ejecutado correctamente.

### 2. SQL Server en server-hdd (Podman, 192.168.3.219)

```sh
cd server-hdd/sql-server
sudo mkdir -p /var/app/mssql
sudo chmod 777 -R /var/app/mssql

# Levantar el servicio
podman compose up -d --remove-orphans
podman compose ps
until podman exec arix-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P 'Sysadmin321++' -Q "SELECT 1" >/dev/null 2>&1; do sleep 5; done
```

Copiar el backup desde esta maquina macOS hacia `server-hdd`:

```sh
scp /Users/vcaxi/Downloads/temp/apibus-trx/To-Be/db_transaction.bak skynet@192.168.3.219:/var/apps/database/mssql/backups/
```

Validar que el backup existe dentro del contenedor:

```sh
podman exec -it arix-mssql ls -lh /var/opt/mssql/backups
```

Leer los nombres logicos del backup:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backups/db_transaction.bak';"
```

Restaurar el backup como `my_db_transaction`, el nombre estable que Debezium leera por CDC. El backup puede venir de otra base o prueba; reemplace solo `<LogicalDataName>` y `<LogicalLogName>` con los valores de `LogicalName` devueltos por `RESTORE FILELISTONLY`:

```sh
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

Validar la restauracion:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "SELECT name, state_desc FROM sys.databases WHERE name = N'my_db_transaction';"
```

Validar que la base restaurada contiene las tres tablas origen de CDC:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -Q "SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID(N'dbo') AND name IN (N'SI_FinKardex', N'SI_FinAgenciaCCE', N'SI_FinCanalCCE');"
```

Habilitar SQL Server Agent, requerido por CDC:

```sh
podman exec -it arix-mssql /opt/mssql/bin/mssql-conf set sqlagent.enabled true
podman restart arix-mssql
until podman exec arix-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P 'Sysadmin321++' -Q "SELECT 1" >/dev/null 2>&1; do sleep 5; done
```

Ejecutar la configuracion CDC sobre `my_db_transaction`. El script valida las tres tablas, habilita CDC solo para ellas y crea el acceso de Debezium:

```sh
podman exec -it arix-mssql /bin/bash /scripts/init-cdc.sh
```

Validar que CDC quedo habilitado en las tres tablas:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -Q "SELECT name, is_tracked_by_cdc FROM sys.tables WHERE name IN (N'SI_FinKardex', N'SI_FinAgenciaCCE', N'SI_FinCanalCCE');"
```

Validar que existe el usuario de Debezium:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -Q "SELECT name FROM sys.database_principals WHERE name = N'debezium';"
```

vaidar si hay CDC
```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -d my_db_transaction \
  -Q "SELECT TOP (10)
        __\$start_lsn,
        __\$operation,
        idAgenciaCCE,
        cNombreOficina,
        lVigente
      FROM cdc.dbo_SI_FinAgenciaCCE_CT
      ORDER BY __\$start_lsn DESC;"
```

CDC se configura sobre la base restaurada `my_db_transaction`. Debezium leera los cambios de estas tres tablas al registrar el Source Connector en Kafka Connect.

No cree una base vacia antes del `RESTORE`: `RESTORE DATABASE [my_db_transaction]` crea o reemplaza la base destino. No configure HADR para esta POC; CDC se habilita exclusivamente con el paso manual anterior.

Para restaurar otro backup de prueba, conserve el nombre destino `my_db_transaction` y actualice unicamente la ruta del backup y sus nombres logicos. Si los conectores ya estan registrados, detenga Source y Sink antes del restore; despues habilite CDC sobre la base restaurada, valide los topicos y reinicialice los conectores segun la estrategia de snapshot y offsets definida para la prueba.

Para eliminar solo el contenedor y red Compose, conservando datos y backups:

```sh
podman compose down
```

### 3. Kafka en server-hdd (Podman, 192.168.3.219)

```sh
sudo mkdir -p /var/app/kafka
sudo chmod 777 -R /var/app/kafka

cd server-hdd/kafka
test -f .env || cp .env.example .env
test -f topics.env || cp topics.env.example topics.env
# In an existing deployment, merge the arify-debezium-* and arify-sink-* variables
# from topics.env.example into topics.env before creating the new internal topics.
podman compose up -d --remove-orphans
podman compose ps
podman exec -it arify-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

Crear los topicos CDC manualmente, despues de que el broker responda:

```sh
set -a
. ./topics.env
set +a

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

# Debezium schema history is durable but not compacted: it can contain records without a key.
podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists --topic "$SCHEMA_HISTORY_TOPIC" \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=delete \
  --config retention.ms=-1
```

Si el topico de historial ya existe como compactado, corrige su configuracion antes de registrar Debezium:

```sh
podman exec -it arify-kafka /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server localhost:9092 \
  --entity-type topics \
  --entity-name "$SCHEMA_HISTORY_TOPIC" \
  --alter \
  --add-config cleanup.policy=delete,retention.ms=-1
```

Valide los topicos antes de iniciar Kafka Connect:

```sh
podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

### 4. Kafka Connect Debezium en server-hdd (Podman, 192.168.3.219)

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

El `.env` de Debezium debe conservar `SQLSERVER_DB=my_db_transaction` y usar `KAFKA_BOOTSTRAP_SERVERS=192.168.3.219:9092` y `SQLSERVER_HOST=192.168.3.219`.

No inicie el Sink ni modifique ScyllaDB hasta que el Source produzca mensajes Kafka. Confirme offset mayor que `0` tras el snapshot o un nuevo cambio CDC:

```sh
podman exec arify-kafka /opt/kafka/bin/kafka-get-offsets.sh \
  --bootstrap-server localhost:9092 \
  --topic sqlserver.my_db_transaction.dbo.SI_FinAgenciaCCE
```

### 5. Kafka Connect Sink en server-hdd (Podman, 192.168.3.219)

Solo despues de que ScyllaDB, sus tablas CQL, rol Sink y el Source se hayan validado:

```sh
cd server-hdd/kafka-connect-sink
test -f .env || cp .env.example .env
nc -vz 192.168.3.219 9092
nc -vz 192.168.3.204 9042
podman compose up -d --remove-orphans
podman compose ps
curl -fsS http://127.0.0.1:8084/connectors
bash register-sink.sh
curl -s http://127.0.0.1:8084/connectors/scylladb-sink/status
```

Registre el Sink solo cuando su task sea `RUNNING`. Produzca entonces un evento manual nuevo para validar `Kafka -> Sink -> ScyllaDB`; no use mensajes publicados antes de registrar el Sink como prueba de aceptación.

## Contratos que deben coincidir

- `SQLSERVER_DB`, `DEBEZIUM_USER` y su secreto deben coincidir entre SQL Server y `kafka-connect-debezium`, aunque se almacenen en `.env` distintos.
- Los topicos CDC de `kafka/topics.env` deben coincidir en ambos workers. Los topicos internos exclusivos `arify-debezium-*` y `arify-sink-*` usan compactacion; `arify-schema-history.sqlserver` usa `cleanup.policy=delete` y `retention.ms=-1`.
- `KAFKA_ADVERTISED_HOST:KAFKA_ADVERTISED_PORT` debe ser alcanzable desde ambos workers y coincidir con `KAFKA_BOOTSTRAP_SERVERS`.
- `SCYLLA_LOCAL_DC` debe ser identico en ScyllaDB y `kafka-connect-sink`.
- `SCYLLA_SINK_USERNAME` y `SCYLLA_SINK_PASSWORD` deben coincidir entre ScyllaDB y `kafka-connect-sink`. Los microservicios usan el rol de solo lectura o roles dedicados, nunca el superusuario `cassandra`.

Los `.env` no se versionan. Consulte el README de cada componente antes de desplegarlo.
