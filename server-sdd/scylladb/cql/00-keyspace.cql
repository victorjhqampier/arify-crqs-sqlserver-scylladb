-- Single-node POC keyspace; production replication must match the ScyllaDB cluster topology.
CREATE KEYSPACE IF NOT EXISTS arify_cqrs
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
