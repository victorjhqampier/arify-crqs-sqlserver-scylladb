# Kafka KRaft

Este componente administra un broker Kafka KRaft y sus topicos. No contiene credenciales ni archivos de SQL Server, Kafka Connect o ScyllaDB.

## Configuracion

Copie ambos archivos de ejemplo:

```sh
cp .env.example .env
cp topics.env.example topics.env
```

`.env` contiene el cluster KRaft y su endpoint externo. Genere `KAFKA_CLUSTER_ID` una sola vez y conserve el valor. `KAFKA_ADVERTISED_HOST` debe ser resoluble desde Kafka Connect.

`topics.env` es el contrato de nombres de topicos: los tres topicos CDC, topicos internos Connect y el historial Debezium. No contiene secretos. Sus nombres deben coincidir con el contrato configurado en Kafka Connect.

Los datos se persisten en `/var/app/kafka`. Cree y otorgue permisos a esa ruta antes del primer arranque segun el usuario de la imagen Kafka.

## Arranque

```sh
docker compose up -d
docker compose ps
docker compose logs kafka-topics-init
```

`kafka-topics-init` crea topicos CDC con retencion de cinco minutos y topicos internos compactados. No se debe registrar Debezium antes de que termine correctamente.
