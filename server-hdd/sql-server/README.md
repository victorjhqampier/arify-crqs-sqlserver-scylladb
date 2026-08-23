# SQL Server

Este componente administra solo SQL Server. No conoce Kafka, Kafka Connect ni ScyllaDB. La restauracion de la base y la preparacion CDC son manuales y visibles.

## Configuracion

Renombre `.env.example` a `.env` y configure `SA_PASSWORD`, `SQLSERVER_DB`, `DEBEZIUM_USER` y `DEBEZIUM_PASSWORD`.

Compose es la definicion de despliegue: un unico contenedor `arix-mssql`, puerto `1433`, reinicio `always`, memoria `3g`, bind mount `/var/app/mssql:/var/opt/mssql` y backups en `/var/apps/database/mssql/backups:/var/opt/mssql/backups`.

## Preparar datos y backup

En `192.168.3.21`, prepare las rutas persistentes antes del primer arranque:

```sh
sudo mkdir -p /var/app/mssql
sudo mkdir -p /var/apps/database/mssql/backups
sudo chmod 777 -R /var/app/mssql /var/apps/database/mssql
```

Desde esta maquina, transfiera el backup al servidor HDD. `scp` no eleva privilegios remotos, por eso se copia primero a `/tmp` y luego se mueve con SSH:

```sh
scp /ruta/local/db_transaction.bak tata@192.168.3.21:/tmp/db_transaction.bak
ssh -t tata@192.168.3.21 "sudo mv /tmp/db_transaction.bak /var/apps/database/mssql/backups/"
```

## Arranque

```sh
mv .env.example .env
podman compose up -d --remove-orphans
podman compose ps
```

Espere hasta que SQL Server responda:

```sh
until podman exec arix-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P 'Sysadmin321++' -Q "SELECT 1" >/dev/null 2>&1; do sleep 5; done
```

## Restaurar db_transaction.bak como my_db_transaction

`my_db_transaction` es el nombre fijo que Debezium captura. El backup puede provenir de otra base o de otra prueba; no cree una base vacia antes del restore y no cambie el nombre destino.

Primero liste los nombres logicos del backup:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backups/db_transaction.bak';"
```

Use los dos nombres devueltos por `LogicalName` en el siguiente comando, sustituyendo `<LogicalDataName>` y `<LogicalLogName>`:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "RESTORE DATABASE [my_db_transaction] FROM DISK = N'/var/opt/mssql/backups/db_transaction.bak' WITH MOVE N'<LogicalDataName>' TO N'/var/opt/mssql/data/my_db_transaction.mdf', MOVE N'<LogicalLogName>' TO N'/var/opt/mssql/data/my_db_transaction_log.ldf', RECOVERY;"
```

Verifique que la base restaurada existe:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "SELECT name FROM sys.databases WHERE name = N'my_db_transaction';"
```

Verifique que las tres tablas fuente existen en la base restaurada:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -Q "SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID(N'dbo') AND name IN (N'SI_FinKardex', N'SI_FinAgenciaCCE', N'SI_FinCanalCCE');"
```

Para probar otro backup, restaurelo nuevamente como `my_db_transaction` y sustituya solo la ruta del backup y los nombres devueltos por `RESTORE FILELISTONLY`. Si los conectores ya estan registrados, detenga Source y Sink antes del restore; despues habilite CDC y reinicialice los conectores de acuerdo con la estrategia de snapshot y offsets de la prueba.

## Habilitar CDC manualmente

CDC requiere SQL Server Agent. Habilitelo una vez y reinicie solo el contenedor SQL Server:

```sh
podman exec -it arix-mssql /opt/mssql/bin/mssql-conf set sqlagent.enabled true
podman restart arix-mssql
until podman exec arix-mssql /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P 'Sysadmin321++' -Q "SELECT 1" >/dev/null 2>&1; do sleep 5; done
```

Ejecute el script manual desde el contenedor. Solo valida las tablas existentes, habilita CDC y crea el acceso `debezium`; nunca crea ni altera tablas de negocio:

```sh
podman exec -it arix-mssql /bin/bash /scripts/init-cdc.sh
```

Valide la captura CDC:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -Q "SELECT name, is_tracked_by_cdc FROM sys.tables WHERE name IN ('SI_FinKardex', 'SI_FinAgenciaCCE', 'SI_FinCanalCCE');"
```

## Eliminar contenedor

```sh
podman compose down
```

Esto elimina el contenedor y la red Compose, pero conserva `/var/app/mssql` y los backups. Para reiniciar la POC desde cero, elimine manualmente esas rutas solo si no necesita conservar datos.
