# SQL Server

Este componente administra solo SQL Server y la preparacion CDC local. No conoce Kafka, Kafka Connect ni ScyllaDB.

## Configuracion

Renombre `.env.example` a `.env` y configure `SA_PASSWORD`, `SQLSERVER_DB`, `DEBEZIUM_USER` y `DEBEZIUM_PASSWORD`.

Compose es la definicion de despliegue: contenedor `arix-mssql`, puerto `1433`, reinicio `always`, memoria `3g` y bind mount `/var/app/mssql:/var/opt/mssql`.

## Inicializador CDC

`sqlserver-init` ejecuta `init/10-enable-cdc.sql` una vez. Valida la base y las tres tablas fuente, habilita CDC y crea el acceso Debezium. Nunca crea ni altera tablas de negocio.

## Arranque

```sh
mv .env.example .env
podman compose up -d
podman compose ps
```

Confirme que `sql-server` este sano y que `sqlserver-init` haya terminado correctamente. SQL Server Agent debe estar habilitado en la instancia existente para que CDC opere.
