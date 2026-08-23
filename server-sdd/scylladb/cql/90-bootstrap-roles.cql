-- Run manually once as cassandra/cassandra after 00-keyspace.cql and 10-proyecciones.cql.
ALTER ROLE cassandra WITH PASSWORD = 'Sysadmin321++' AND LOGIN = true AND SUPERUSER = true;

CREATE ROLE IF NOT EXISTS arify_kafka_sink
WITH PASSWORD = 'Sysadmin321++'
AND LOGIN = true
AND SUPERUSER = false;
ALTER ROLE arify_kafka_sink WITH PASSWORD = 'Sysadmin321++' AND LOGIN = true AND SUPERUSER = false;
GRANT MODIFY ON KEYSPACE arify_cqrs TO arify_kafka_sink;

CREATE ROLE IF NOT EXISTS arify_readonly
WITH PASSWORD = 'Sysadmin321++'
AND LOGIN = true
AND SUPERUSER = false;
ALTER ROLE arify_readonly WITH PASSWORD = 'Sysadmin321++' AND LOGIN = true AND SUPERUSER = false;
GRANT SELECT ON KEYSPACE arify_cqrs TO arify_readonly;
