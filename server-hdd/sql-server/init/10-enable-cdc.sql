-- Enables CDC only for the three approved tables and grants the Debezium login least required access.
IF DB_ID(N'$(DB_NAME)') IS NULL
    THROW 50000, 'The configured SQLSERVER_DB does not exist.', 1;
GO

USE [$(DB_NAME)];
GO

IF OBJECT_ID(N'dbo.SI_FinKardex', N'U') IS NULL
   OR OBJECT_ID(N'dbo.SI_FinAgenciaCCE', N'U') IS NULL
   OR OBJECT_ID(N'dbo.SI_FinCanalCCE', N'U') IS NULL
    THROW 50001, 'The three CDC source tables must exist before enabling CDC.', 1;
GO

IF (SELECT is_cdc_enabled FROM sys.databases WHERE name = N'$(DB_NAME)') = 0
    EXEC sys.sp_cdc_enable_db;
GO

IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.SI_FinKardex'))
    EXEC sys.sp_cdc_enable_table @source_schema = N'dbo', @source_name = N'SI_FinKardex', @role_name = NULL, @supports_net_changes = 1;

IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.SI_FinAgenciaCCE'))
    EXEC sys.sp_cdc_enable_table @source_schema = N'dbo', @source_name = N'SI_FinAgenciaCCE', @role_name = NULL, @supports_net_changes = 1;

IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID(N'dbo.SI_FinCanalCCE'))
    EXEC sys.sp_cdc_enable_table @source_schema = N'dbo', @source_name = N'SI_FinCanalCCE', @role_name = NULL, @supports_net_changes = 1;
GO

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = N'$(DEBEZIUM_USER)')
    EXEC(N'CREATE LOGIN [$(DEBEZIUM_USER)] WITH PASSWORD = N''$(DEBEZIUM_PASSWORD)'', CHECK_POLICY = ON;');
GO

-- Lets Debezium verify that SQL Server Agent is running while it reads CDC tables.
GRANT VIEW SERVER STATE TO [$(DEBEZIUM_USER)];
GRANT VIEW SERVER PERFORMANCE STATE TO [$(DEBEZIUM_USER)];
GO

USE [$(DB_NAME)];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$(DEBEZIUM_USER)')
    CREATE USER [$(DEBEZIUM_USER)] FOR LOGIN [$(DEBEZIUM_USER)];

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals role_principal ON role_principal.principal_id = drm.role_principal_id
    JOIN sys.database_principals member_principal ON member_principal.principal_id = drm.member_principal_id
    WHERE role_principal.name = N'db_datareader' AND member_principal.name = N'$(DEBEZIUM_USER)'
)
    ALTER ROLE db_datareader ADD MEMBER [$(DEBEZIUM_USER)];

GRANT VIEW DATABASE STATE TO [$(DEBEZIUM_USER)];
GRANT SELECT ON SCHEMA::cdc TO [$(DEBEZIUM_USER)];
GRANT EXECUTE ON SCHEMA::cdc TO [$(DEBEZIUM_USER)];
GO
