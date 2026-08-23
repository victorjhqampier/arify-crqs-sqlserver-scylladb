# ScyllaDB

Este componente administra los modelos de lectura CQL. No conoce Kafka, Kafka Connect ni SQL Server.

## Configuracion

```sh
mv .env.example .env
```

Compose es la definicion de despliegue: un unico contenedor `arify-scylladb`, imagen fija `scylladb/scylla:5.4.9`, puerto `9042`, reinicio `always`, bind mount `/var/apps/scylladb/data:/var/lib/scylla`, `--smp 2`, `--memory 2G` y `--overprovisioned 1`.

`SCYLLA_LOCAL_DC` debe coincidir con el valor configurado en Kafka Connect. Actualice `cql/10-proyecciones.cql` a partir de las consultas de lectura y el DDL real; no replique el esquema SQL Server literalmente.

La autenticacion CQL y autorizacion estan activas. El bootstrap es manual y visible: se conecta primero con `cassandra/cassandra`, cambia la clave mediante `cql/80-bootstrap-superuser.cql`, aplica los esquemas y ejecuta `cql/90-bootstrap-roles.cql` con la clave nueva. El ultimo archivo crea `arify_kafka_sink` con permiso `MODIFY` y `arify_readonly` con permiso `SELECT` sobre `arify_cqrs`.

No use el superusuario `cassandra` en Kafka Connect ni en microservicios. Si ya existe una instancia con datos en `/var/apps/scylladb/data`, respalde y pruebe el reinicio: activar autenticacion corta a los clientes sin credenciales.

## Arranque

```sh
docker compose up -d
docker compose ps
```

Para un inicio limpio, elimine el contenedor y el directorio de datos antes de levantarlo. Esto borra todos los datos, keyspaces y roles de ScyllaDB:

```sh
docker compose down
sudo rm -rf /var/apps/scylladb/data
sudo mkdir -p /var/apps/scylladb/data
sudo chmod 777 /var/apps/scylladb/data
docker compose up -d --force-recreate
```

Cuando el contenedor este `Up`, ejecute una sola vez desde esta carpeta:

```sh
docker exec -i arify-scylladb cqlsh -u cassandra -p cassandra < cql/00-keyspace.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p cassandra < cql/10-proyecciones.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p cassandra < cql/80-bootstrap-superuser.cql
docker exec -i arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++' < cql/90-bootstrap-roles.cql
docker exec -it arify-scylladb cqlsh -u cassandra -p 'Sysadmin321++'
```

Antes de registrar el Sink, permita acceso desde Kafka Connect al puerto `9042` y confirme que existen el keyspace, tablas y roles.

## Recrear servicios

Para recrear los contenedores despues de un cambio de Compose sin borrar datos del bind mount:

```sh
docker compose up -d --force-recreate
```
