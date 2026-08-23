# POC CQRS con CDC

Flujo: `SQL Server (CDC) -> Debezium -> Kafka KRaft -> Kafka Connect Sink -> ScyllaDB`.

Cada componente tiene su propio Compose, variables, red Docker y README. Puede vivir en otro servidor o repositorio. Ningun Compose usa `depends_on`, DNS o archivos `.env` de otro componente.

## Componentes

| Componente | Compose | Contrato externo |
| --- | --- | --- |
| SQL Server | `server-hdd/sql-server/` | Expone SQL Server en `1433`. |
| Kafka | `server-hdd/kafka/` | Expone el broker configurado en `KAFKA_ADVERTISED_HOST:KAFKA_ADVERTISED_PORT`. |
| Kafka Connect | `server-hdd/kafka-connect/` | Recibe endpoints de SQL Server, Kafka y ScyllaDB en su propio `.env`. |
| ScyllaDB | `server-sdd/scylladb/` | Expone CQL en `9042`. |

## Preparacion

En cada servidor, renombre los archivos de configuracion una sola vez. Luego edite los valores reales antes de levantar los servicios.

```sh
# En 192.168.3.204 (server-sdd)
mv server-sdd/scylladb/.env.example server-sdd/scylladb/.env

# En 192.168.3.21 (server-hdd)
mv server-hdd/sql-server/.env.example server-hdd/sql-server/.env
mv server-hdd/kafka/.env.example server-hdd/kafka/.env
mv server-hdd/kafka/topics.env.example server-hdd/kafka/topics.env
mv server-hdd/kafka-connect/.env.example server-hdd/kafka-connect/.env
```

Configure estas IPs antes del arranque:

```env
# server-hdd/kafka/.env
KAFKA_ADVERTISED_HOST=192.168.3.21

# server-hdd/kafka-connect/.env
SQLSERVER_HOST=192.168.3.21
KAFKA_BOOTSTRAP_SERVERS=192.168.3.21:9092
SCYLLA_CONTACT_POINTS=192.168.3.204
```

## Orden de ejecucion

### 1. ScyllaDB en server-sdd (Docker, 192.168.3.204)

```sh
sudo mkdir -p /var/apps/scylladb/data && sudo chmod 777 -R /var/apps/scylladb

cd server-sdd/scylladb
docker compose up -d
docker compose ps
docker compose logs cql-init

docker compose down -v
```

Continue solo cuando `scylladb` este sano y `cql-init` haya terminado correctamente.

### 2. SQL Server en server-hdd (Podman, 192.168.3.21)

```sh
cd server-hdd/sql-server
podman compose up -d
podman compose ps
podman compose logs sqlserver-init
```

Continue solo cuando `sql-server` este sano y `sqlserver-init` haya terminado correctamente.

### 3. Kafka en server-hdd (Podman, 192.168.3.21)

```sh
cd server-hdd/kafka
podman compose up -d
podman compose ps
podman compose logs kafka-topics-init
```

Continue solo cuando `kafka` este sano y `kafka-topics-init` haya terminado correctamente.

### 4. Kafka Connect en server-hdd (Podman, 192.168.3.21)

```sh
cd server-hdd/kafka-connect
podman compose up -d
podman compose ps
curl -fsS http://127.0.0.1:8083/connectors
```

### 5. Registro de conectores en server-hdd

```sh
cd server-hdd/kafka-connect
bash kafka-debizium.sh
curl -s http://127.0.0.1:8083/connectors?expand=status
```

Registre los conectores solo despues de confirmar que ScyllaDB, el esquema CQL, SQL Server y los topicos Kafka estan preparados. SQL Server y Kafka pueden arrancar en paralelo, pero la secuencia anterior evita registrar conectores contra dependencias aun no preparadas.

## Contratos que deben coincidir

- `SQLSERVER_DB`, `DEBEZIUM_USER` y su secreto deben coincidir entre el componente SQL Server y Kafka Connect, aunque se almacenen en `.env` distintos.
- Los topicos de `kafka/topics.env` deben copiarse sin cambios al `.env` de Kafka Connect.
- `KAFKA_ADVERTISED_HOST:KAFKA_ADVERTISED_PORT` debe ser alcanzable desde Kafka Connect y coincidir con `KAFKA_BOOTSTRAP_SERVERS`.
- `SCYLLA_LOCAL_DC` debe ser identico en ScyllaDB y Kafka Connect.
- `SCYLLA_SINK_USERNAME` y `SCYLLA_SINK_PASSWORD` deben coincidir entre ScyllaDB y Kafka Connect. Los microservicios usan el rol de solo lectura o roles dedicados, nunca el superusuario `cassandra`.

Los `.env` no se versionan. Consulte el README de cada componente antes de desplegarlo.
