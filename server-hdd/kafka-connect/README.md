# Kafka Connect

Este componente ejecuta Debezium SQL Server Source y el Sink DataStax hacia ScyllaDB. Se integra con servicios externos solo mediante endpoints configurados en su propio `.env`.

## Configuracion

```sh
cp .env.example .env
```

Configure los endpoints `KAFKA_BOOTSTRAP_SERVERS`, `SQLSERVER_HOST` y `SCYLLA_CONTACT_POINTS`; los secretos Debezium; las credenciales `SCYLLA_SINK_USERNAME` y `SCYLLA_SINK_PASSWORD` del rol de escritura; y los nombres de topicos copiados manualmente desde el contrato publicado por el componente Kafka.

`connectors/debezium-sqlserver.json` recibe valores por variables de entorno. `connectors/scylladb-sink.json.template` se renderiza localmente durante el registro porque los nombres de topico son parte de las claves de mapeo. Reemplace las columnas placeholder por el DDL y las consultas de lectura reales.

## Arranque y registro

```sh
docker compose up -d
bash kafka-debizium.sh
```

Ejecute el registro solo cuando Kafka tenga sus topicos y ScyllaDB tenga keyspace y tablas CQL. La API REST se expone en `127.0.0.1:8083`.
