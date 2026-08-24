# Consultas SQL Server Para Modelado CDC y ScyllaDB

Estas consultas recopilan el contrato necesario para definir el mapeo SQL Server -> Debezium -> Kafka -> ScyllaDB de las tablas `dbo.SI_FinKardex`, `dbo.SI_FinAgenciaCCE` y `dbo.SI_FinCanalCCE`.

Ejecutelas contra la base restaurada estable `my_db_transaction`. Revise las muestras de datos segun las politicas de acceso aplicables.

## 1. Describir columnas

Identifica nombres, tipos, longitudes, precision, nullabilidad, identidad y valores por defecto.

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -W -s "|" \
  -Q "
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    c.column_id,
    c.name AS column_name,
    ty.name AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable,
    c.is_identity,
    ISNULL(dc.definition, N'') AS default_definition
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
LEFT JOIN sys.default_constraints dc
    ON dc.parent_object_id = t.object_id
   AND dc.parent_column_id = c.column_id
WHERE s.name = N'dbo'
  AND t.name IN (N'SI_FinKardex', N'SI_FinAgenciaCCE', N'SI_FinCanalCCE')
ORDER BY t.name, c.column_id;"
```

## 2. Claves primarias

Las claves primarias SQL Server forman la `key` del evento Debezium y son la primera referencia para definir la clave de la proyeccion CQL.

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -W -s "|" \
  -Q "
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    kc.name AS constraint_name,
    c.name AS column_name,
    ic.key_ordinal
FROM sys.key_constraints kc
JOIN sys.tables t ON t.object_id = kc.parent_object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.index_columns ic
    ON ic.object_id = t.object_id
   AND ic.index_id = kc.unique_index_id
JOIN sys.columns c
    ON c.object_id = t.object_id
   AND c.column_id = ic.column_id
WHERE kc.type = 'PK'
  AND s.name = N'dbo'
  AND t.name IN (N'SI_FinKardex', N'SI_FinAgenciaCCE', N'SI_FinCanalCCE')
ORDER BY t.name, ic.key_ordinal;"
```

## 3. Indices y claves alternativas

Muestra los indices disponibles para identificar posibles claves de particion y tablas CQL orientadas a consultas.

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -W -s "|" \
  -Q "
SELECT
    s.name AS schema_name,
    t.name AS table_name,
    i.name AS index_name,
    i.is_unique,
    i.is_primary_key,
    c.name AS column_name,
    ic.key_ordinal,
    ic.is_included_column
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.index_columns ic
    ON ic.object_id = i.object_id
   AND ic.index_id = i.index_id
JOIN sys.columns c
    ON c.object_id = t.object_id
   AND c.column_id = ic.column_id
WHERE s.name = N'dbo'
  AND t.name IN (N'SI_FinKardex', N'SI_FinAgenciaCCE', N'SI_FinCanalCCE')
  AND i.name IS NOT NULL
ORDER BY t.name, i.name, ic.key_ordinal, ic.index_column_id;"
```

## 4. Estado CDC

Confirma que las tres tablas se encuentran habilitadas para la captura de cambios.

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -W -s "|" \
  -Q "
SELECT name AS table_name, is_tracked_by_cdc
FROM sys.tables
WHERE schema_id = SCHEMA_ID(N'dbo')
  AND name IN (N'SI_FinKardex', N'SI_FinAgenciaCCE', N'SI_FinCanalCCE')
ORDER BY name;"
```

## 5. Columnas capturadas por CDC

Confirma las columnas que Debezium recibira desde cada instancia de captura.

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -W -s "|" \
  -Q "
SELECT
    ct.capture_instance,
    OBJECT_SCHEMA_NAME(ct.source_object_id) AS schema_name,
    OBJECT_NAME(ct.source_object_id) AS table_name,
    cc.column_name,
    cc.column_ordinal
FROM cdc.change_tables ct
JOIN cdc.captured_columns cc ON cc.object_id = ct.object_id
WHERE OBJECT_SCHEMA_NAME(ct.source_object_id) = N'dbo'
  AND OBJECT_NAME(ct.source_object_id) IN (N'SI_FinKardex', N'SI_FinAgenciaCCE', N'SI_FinCanalCCE')
ORDER BY table_name, cc.column_ordinal;"
```

## 6. Conteo de filas

Ayuda a estimar el tamano inicial del snapshot de Debezium y las proyecciones CQL.

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -W -s "|" \
  -Q "
SELECT N'SI_FinKardex' AS table_name, COUNT_BIG(*) AS rows_count FROM dbo.SI_FinKardex
UNION ALL
SELECT N'SI_FinAgenciaCCE', COUNT_BIG(*) FROM dbo.SI_FinAgenciaCCE
UNION ALL
SELECT N'SI_FinCanalCCE', COUNT_BIG(*) FROM dbo.SI_FinCanalCCE;"
```

## 7. Muestras de datos

Use estas muestras para confirmar formatos y valores reales antes de elegir tipos CQL y mappings del Sink.

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -W -s "|" -Q "SELECT TOP 20 * FROM dbo.SI_FinKardex;"
```

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -W -s "|" -Q "SELECT TOP 20 * FROM dbo.SI_FinAgenciaCCE;"
```

```sh
podman exec -it arix-mssql /opt/mssql-tools18/bin/sqlcmd \
  -C -S localhost -U sa -P 'Sysadmin321++' -d my_db_transaction \
  -W -s "|" -Q "SELECT TOP 20 * FROM dbo.SI_FinCanalCCE;"
```
