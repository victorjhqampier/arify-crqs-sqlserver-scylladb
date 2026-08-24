# Kafka Connect

Este componente ejecuta Debezium SQL Server Source y el Sink DataStax hacia ScyllaDB. Se integra con servicios externos solo mediante endpoints configurados en su propio `.env`.

## Configuracion

```sh
test -f .env || cp .env.example .env
```

El ejemplo usa los endpoints de la POC: Kafka `192.168.3.219:9092`, SQL Server `192.168.3.219:1433` y ScyllaDB `192.168.3.204:9042`. Mantenga `SQLSERVER_DB=my_db_transaction`, los topicos publicados por Kafka y los secretos Debezium/ScyllaDB adecuados para el entorno.

Valide la conectividad antes de iniciar Kafka Connect:

```sh
nc -vz 192.168.3.219 9092
nc -vz 192.168.3.219 1433
nc -vz 192.168.3.204 9042
```

`connectors/debezium-sqlserver.json` recibe valores por variables de entorno. `connectors/scylladb-sink.json.template` se renderiza localmente durante el registro porque los nombres de topico son parte de las claves de mapeo. Reemplace las columnas placeholder por el DDL y las consultas de lectura reales.

## Arranque y registro

```sh
podman compose up -d --remove-orphans
podman compose ps
curl -fsS http://127.0.0.1:8083/connectors
bash kafka-debizium.sh
```

Ejecute el registro solo cuando Kafka tenga sus topicos y ScyllaDB tenga keyspace y tablas CQL. La API REST se expone en `127.0.0.1:8083`.
