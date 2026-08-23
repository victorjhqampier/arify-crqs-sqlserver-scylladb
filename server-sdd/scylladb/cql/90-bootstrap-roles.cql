-- Run manually as cassandra/Sysadmin321++ after changing the bootstrap superuser password.

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
