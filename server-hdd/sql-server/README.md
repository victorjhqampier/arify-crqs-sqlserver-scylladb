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
scp /ruta/local/DB_Financiero.bak tata@192.168.3.21:/tmp/DB_Financiero.bak
ssh tata@192.168.3.21 "sudo mv /tmp/DB_Financiero.bak /var/apps/database/mssql/backups/"
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

## Restaurar DB_Financiero.bak como Arify

Primero liste los nombres logicos del backup:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "RESTORE FILELISTONLY FROM DISK = N'/var/opt/mssql/backups/DB_Financiero.bak';"
```

Use los dos nombres devueltos por `LogicalName` en el siguiente comando, sustituyendo `<LogicalDataName>` y `<LogicalLogName>`:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "RESTORE DATABASE [Arify] FROM DISK = N'/var/opt/mssql/backups/DB_Financiero.bak' WITH MOVE N'<LogicalDataName>' TO N'/var/opt/mssql/data/Arify.mdf', MOVE N'<LogicalLogName>' TO N'/var/opt/mssql/data/Arify_log.ldf', RECOVERY;"
```

Verifique que la base restaurada existe:

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' \
  -Q "SELECT name FROM sys.databases WHERE name = N'Arify';"
```

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
  -C -S localhost -U sa -P 'Sysadmin321++' -d Arify \
  -Q "SELECT name, is_tracked_by_cdc FROM sys.tables WHERE name IN ('SI_FinKardex', 'SI_FinAgenciaCCE', 'SI_FinCanalCCE');"
```

## Eliminar contenedor

```sh
podman compose down
```

Esto elimina el contenedor y la red Compose, pero conserva `/var/app/mssql` y los backups. Para reiniciar la POC desde cero, elimine manualmente esas rutas solo si no necesita conservar datos.
