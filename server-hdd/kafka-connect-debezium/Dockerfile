# Kafka Connect worker dedicated to the Debezium SQL Server source plugin.
ARG CP_KAFKA_CONNECT_VERSION=7.7.1
FROM confluentinc/cp-kafka-connect:${CP_KAFKA_CONNECT_VERSION}

ARG DEBEZIUM_VERSION=2.7.3.Final

USER root
RUN mkdir -p /usr/share/kafka/plugins \
    && curl -fsSL -o /tmp/debezium-sqlserver-plugin.tar.gz \
      "https://repo1.maven.org/maven2/io/debezium/debezium-connector-sqlserver/${DEBEZIUM_VERSION}/debezium-connector-sqlserver-${DEBEZIUM_VERSION}-plugin.tar.gz" \
    && tar -xzf /tmp/debezium-sqlserver-plugin.tar.gz -C /usr/share/kafka/plugins \
    && rm /tmp/debezium-sqlserver-plugin.tar.gz

COPY plugins/ /opt/kafka-connect/custom-plugins/
USER appuser
