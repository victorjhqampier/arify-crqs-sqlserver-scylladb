# ScyllaDB

Este componente administra los modelos de lectura CQL. No conoce Kafka, Kafka Connect ni SQL Server.

## Configuracion

```sh
mv .env.example .env
```

Compose es la definicion de despliegue: un unico contenedor `arify-scylladb`, imagen fija `scylladb/scylla:5.4.9`, puerto `9042`, reinicio `always`, bind mount `/var/apps/scylladb/data:/var/lib/scylla`, `--smp 2`, `--memory 2G` y `--overprovisioned 1`.

`SCYLLA_LOCAL_DC` debe coincidir con el valor configurado en Kafka Connect. Actualice `cql/10-proyecciones.cql` a partir de las consultas de lectura y el DDL real; no replique el esquema SQL Server literalmente.

La autenticacion CQL y autorizacion estan activas. En un arranque limpio, ScyllaDB expone el bootstrap `cassandra/cassandra`. Cambie esa clave manualmente a `Sysadmin321++`, aplique los esquemas y ejecute `cql/90-bootstrap-roles.cql` con la clave nueva. El ultimo archivo crea `arify_kafka_sink` con permiso `MODIFY` y `arify_readonly` con permiso `SELECT` sobre `arify_cqrs`.

No use el superusuario `cassandra` en Kafka Connect ni en microservicios. Si ya existe una instancia con datos en `/var/apps/scylladb/data`, respalde y pruebe el reinicio: activar autenticacion corta a los clientes sin credenciales.

## Arranque

El arranque normal conserva los datos existentes:

```sh
sudo mkdir -p /var/apps/scylladb/data
sudo chmod 777 -R /var/apps/scylladb
docker compose up -d --remove-orphans
docker compose ps
until docker logs arify-scylladb 2>&1 | grep -q "initialization completed"; do sleep 5; done
```

Para un inicio limpio, elimine el contenedor y el directorio de datos antes de levantarlo. Esto borra todos los datos, keyspaces y roles de ScyllaDB:

```sh
docker compose down
sudo rm -rf /var/apps/scylladb/data
sudo mkdir -p /var/apps/scylladb/data
sudo chmod 777 -R /var/apps/scylladb
docker compose up -d --force-recreate --remove-orphans
until docker logs arify-scylladb 2>&1 | grep -q "initialization completed"; do sleep 5; done
```

Cuando aparezca `initialization completed`, ejecute el bootstrap manual una sola vez desde esta carpeta:

```sh
docker exec -i arify-scylladb cqlsh -u cassandra -p cassandra -e "ALTER ROLE cassandra WITH PASSWORD = 'Sysadmin321++';"
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/00-keyspace.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/10-proyecciones.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/90-bootstrap-roles.cql
docker exec -it arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++'
```

En arranques posteriores con el mismo directorio de datos, no repita el bootstrap: valide directamente con `cassandra/Sysadmin321++`.

Antes de registrar el Sink, permita acceso desde Kafka Connect al puerto `9042` y confirme que existen el keyspace, tablas y roles.

## Recrear servicios

Para recrear los contenedores despues de un cambio de Compose sin borrar datos del bind mount:

```sh
docker compose up -d --force-recreate
```
