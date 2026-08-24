# Kafka KRaft

Este componente administra un broker Kafka KRaft. Los topicos se crean manualmente despues de que el broker este disponible. No contiene credenciales ni archivos de SQL Server, Kafka Connect o ScyllaDB.

## Configuracion

Copie ambos archivos de ejemplo:

```sh
test -f .env || cp .env.example .env
test -f topics.env || cp topics.env.example topics.env
```

`.env` contiene el cluster KRaft y su endpoint externo. Genere `KAFKA_CLUSTER_ID` una sola vez y conserve el valor. `KAFKA_ADVERTISED_HOST` debe ser resoluble desde Kafka Connect.

`topics.env` es el contrato de nombres de topicos: los tres topicos CDC, topicos internos Connect y el historial Debezium. No contiene secretos. Sus nombres deben coincidir con el contrato configurado en Kafka Connect.

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

Crear los topicos internos de Kafka Connect y el historial de Debezium como compactados, sin la retencion de cinco minutos:

```sh
for topic in "$CONNECT_CONFIG_TOPIC" "$CONNECT_OFFSET_TOPIC" "$CONNECT_STATUS_TOPIC" "$SCHEMA_HISTORY_TOPIC"; do
  podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --create --if-not-exists --topic "$topic" \
    --partitions 1 --replication-factor 1 \
    --config cleanup.policy=compact
done
```

Valide los topicos antes de registrar Debezium:

```sh
podman exec -it arify-kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --list
```


## conandos
skynet  …/arify-crqs-sqlserver-scylladb/server-hdd/kafka-connect   main ?    podman exec -it arify-kafka /opt/kafka/bin/kafka-get-offsets.sh   --bootstrap-server localhost:9092   --topic sqlserver.my_db_transaction.dbo.SI_FinAgenciaCCE
sqlserver.my_db_transaction.dbo.SI_FinAgenciaCCE:0:0
