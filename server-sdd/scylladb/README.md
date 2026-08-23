# ScyllaDB

Este componente administra los modelos de lectura CQL. No conoce Kafka, Kafka Connect ni SQL Server.

## Configuracion

```sh
mv .env.example .env
```

Compose es la definicion de despliegue: contenedor y hostname `arify-scylladb`, puerto `9042`, reinicio `always`, bind mount `/var/apps/scylladb/data:/var/lib/scylla`, `--smp 2`, `--memory 2G` y `--overprovisioned 1`.

`SCYLLA_LOCAL_DC` debe coincidir con el valor configurado en Kafka Connect. Actualice `cql/10-proyecciones.cql` a partir de las consultas de lectura y el DDL real; no replique el esquema SQL Server literalmente.

La autenticacion CQL y autorizacion estan activas. En el primer arranque, `init-cql.sh` accede con el bootstrap `cassandra/cassandra`, cambia inmediatamente la clave por `SCYLLA_SUPERUSER_PASSWORD` y crea:

- `SCYLLA_SINK_USERNAME`: permiso `MODIFY` sobre `arify_cqrs`, exclusivo para Kafka Connect.
- `SCYLLA_READONLY_USERNAME`: permiso `SELECT` sobre `arify_cqrs`, base para consumidores de lectura. Cree un rol equivalente por microservicio cuando requiera aislamiento adicional.

No use el superusuario `cassandra` en Kafka Connect ni en microservicios. Si ya existe una instancia con datos en `/var/apps/scylladb/data`, respalde y pruebe el reinicio: activar autenticacion corta a los clientes sin credenciales.

## Arranque

```sh
docker compose up -d
docker compose ps
```

`cql-init` inicia junto a ScyllaDB, espera CQL autenticado durante un maximo de 120 segundos y luego aplica los CQL y roles. Antes de registrar el Sink, confirme que haya terminado correctamente y permita acceso desde Kafka Connect al puerto `9042`.

## Recrear servicios

Para recrear los contenedores despues de un cambio de Compose sin borrar datos del bind mount:

```sh
docker compose up -d --force-recreate
```
