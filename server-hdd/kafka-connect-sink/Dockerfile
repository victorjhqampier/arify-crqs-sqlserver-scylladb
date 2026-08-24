# Kafka Connect worker dedicated to the DataStax Cassandra-compatible Sink plugin.
ARG CP_KAFKA_CONNECT_VERSION=7.7.1
FROM confluentinc/cp-kafka-connect:${CP_KAFKA_CONNECT_VERSION}

ARG DATASTAX_SINK_VERSION=1.7.6
ARG DATASTAX_SINK_SHA256

USER root
RUN mkdir -p /usr/share/kafka/plugins/datastax-cassandra-sink \
    && curl -fsSL -o /usr/share/kafka/plugins/datastax-cassandra-sink/kafka-connect-cassandra-sink.jar \
      "https://github.com/datastax/kafka-sink/releases/download/${DATASTAX_SINK_VERSION}/kafka-connect-cassandra-sink-${DATASTAX_SINK_VERSION}.jar" \
    && echo "${DATASTAX_SINK_SHA256}  /usr/share/kafka/plugins/datastax-cassandra-sink/kafka-connect-cassandra-sink.jar" | sha256sum -c -

COPY plugins/ /opt/kafka-connect/custom-plugins/
USER appuser
