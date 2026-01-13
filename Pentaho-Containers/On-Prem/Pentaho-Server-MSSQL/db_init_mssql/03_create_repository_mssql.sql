-- =========================================================
-- Pentaho Hibernate Repository Database Creation - SQL Server
-- =========================================================

-- Create hibernate database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'hibernate')
BEGIN
    CREATE DATABASE hibernate;
    PRINT 'Database hibernate created successfully';
END
ELSE
BEGIN
    PRINT 'Database hibernate already exists';
END
GO

USE hibernate;
GO

-- Create hibuser login if not exists
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'hibuser')
BEGIN
    CREATE LOGIN hibuser WITH PASSWORD = 'password', CHECK_POLICY = OFF;
    PRINT 'Login hibuser created successfully';
END
ELSE
BEGIN
    PRINT 'Login hibuser already exists';
END
GO

-- Create user in database if not exists
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'hibuser')
BEGIN
    CREATE USER hibuser FOR LOGIN hibuser;
    PRINT 'User hibuser created in hibernate database';
END
ELSE
BEGIN
    PRINT 'User hibuser already exists in hibernate database';
END
GO

-- Grant permissions
ALTER ROLE db_owner ADD MEMBER hibuser;
GO

PRINT 'Hibernate database setup completed';
GO
