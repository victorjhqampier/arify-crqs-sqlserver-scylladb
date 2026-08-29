# Kafka KRaft

Este componente administra un broker Kafka KRaft. Los topicos se crean manualmente despues de que el broker este disponible. No contiene credenciales ni archivos de SQL Server, Kafka Connect o ScyllaDB.

## Configuracion

Copie ambos archivos de ejemplo:

```sh
test -f .env || cp .env.example .env
test -f topics.env || cp topics.env.example topics.env
```

`.env` contiene el cluster KRaft y su endpoint externo. Genere `KAFKA_CLUSTER_ID` una sola vez y conserve el valor. `KAFKA_ADVERTISED_HOST` debe ser resoluble desde ambos workers Kafka Connect.

`topics.env` es el contrato de nombres de topicos: los tres topicos CDC compartidos, los topicos internos exclusivos de cada worker y el historial Debezium. No contiene secretos. Sus nombres deben coincidir con los `.env` de los componentes Connect.

Los datos se persisten en `/var/app/kafka`. Cree y otorgue permisos a esa ruta antes del primer arranque segun el usuario de la imagen Kafka.

## Arranque del broker

```sh
podman compose up -d --remove-orphans
podman compose ps
```

Valide que el broker responde antes de crear topicos:

```sh
podman exec -it arify-kafka /opt/kafka/bin/kafka-broker-api-versions.sh \
  --bootstrap-server localhost:9092
```

## Crear topicos manualmente

Desde este directorio, cargue el contrato de topicos y cree los tres topicos CDC con retencion de cinco minutos:

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
```

Crear solo los topicos internos exclusivos de ambos workers como compactados, sin la retencion de cinco minutos:

```sh
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
```

Crear el historial de esquema de Debezium como durable y no compactado. Debezium escribe algunos registros sin key, por lo que `cleanup.policy=compact` rechaza el snapshot:

```sh
podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --if-not-exists --topic "$SCHEMA_HISTORY_TOPIC" \
  --partitions 1 --replication-factor 1 \
  --config cleanup.policy=delete \
  --config retention.ms=-1
```

Si el historial ya existia como compactado, corrijalo antes de registrar Debezium:

```sh
podman exec -it arify-kafka /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server localhost:9092 \
  --entity-type topics \
  --entity-name "$SCHEMA_HISTORY_TOPIC" \
  --alter \
  --add-config cleanup.policy=delete,retention.ms=-1
```

Valide los topicos antes de registrar Debezium:

```sh
podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --list
```
