# Connector templates

`debezium-sqlserver.json` se registra sin renderizar y recibe endpoints mediante variables de entorno de Kafka Connect. `scylladb-sink.json.template` se renderiza localmente con los nombres de topicos y keyspace del `.env` de este componente; mapea los tres topicos CDC a `si_fin_kardex`, `si_fin_agencia_cce` y `si_fin_canal_cce`. Como las columnas CQL no estan entre comillas, el lado izquierdo de cada mapping usa sus nombres en minusculas. Las tablas SQL Server ya existen y este repositorio nunca las crea.
