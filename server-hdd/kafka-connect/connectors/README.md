# Connector templates

`debezium-sqlserver.json` se registra sin renderizar y recibe endpoints mediante variables de entorno de Kafka Connect. `scylladb-sink.json.template` se renderiza localmente con los nombres de topicos y keyspace del `.env` de este componente. Actualice sus columnas placeholder con el DDL y las consultas de lectura reales antes de registrarlo. Las tablas SQL Server ya existen y este repositorio nunca las crea.
