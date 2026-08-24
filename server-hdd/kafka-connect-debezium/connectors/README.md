# Debezium Source Connector

`debezium-sqlserver.json` is registered only through `../register-debezium.sh` against this worker's REST API on port `8083`.

The connector reads only the three configured `dbo.SI_Fin*` source tables and publishes JSON without schemas. Runtime endpoints and credentials are resolved from this component's non-versioned `.env` through the Kafka Connect `env` config provider.
