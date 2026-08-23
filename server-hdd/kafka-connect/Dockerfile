# Installs the SQL Server source and CQL sink plugins into one Kafka Connect worker image.
ARG CP_KAFKA_CONNECT_VERSION=7.7.1
FROM confluentinc/cp-kafka-connect:${CP_KAFKA_CONNECT_VERSION}

ARG DEBEZIUM_VERSION=2.7.3
ARG DATASTAX_SINK_VERSION=1.7.6
ARG DATASTAX_SINK_SHA256

USER root
RUN confluent-hub install --no-prompt debezium/debezium-connector-sqlserver:${DEBEZIUM_VERSION} \
    && mkdir -p /usr/share/kafka/plugins/datastax-cassandra-sink \
    && curl -fsSL -o /usr/share/kafka/plugins/datastax-cassandra-sink/kafka-connect-cassandra-sink.jar \
      "https://github.com/datastax/kafka-sink/releases/download/${DATASTAX_SINK_VERSION}/kafka-connect-cassandra-sink-${DATASTAX_SINK_VERSION}.jar" \
    && echo "${DATASTAX_SINK_SHA256}  /usr/share/kafka/plugins/datastax-cassandra-sink/kafka-connect-cassandra-sink.jar" | sha256sum -c -

COPY plugins/ /usr/share/kafka/plugins/
USER appuser
