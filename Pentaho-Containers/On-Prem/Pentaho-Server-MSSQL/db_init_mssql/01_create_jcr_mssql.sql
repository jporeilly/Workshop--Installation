-- =========================================================
-- Pentaho Jackrabbit (JCR) Database Creation - SQL Server
-- =========================================================

-- Create jackrabbit database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'jackrabbit')
BEGIN
    CREATE DATABASE jackrabbit;
    PRINT 'Database jackrabbit created successfully';
END
ELSE
BEGIN
    PRINT 'Database jackrabbit already exists';
END
GO

USE jackrabbit;
GO

-- Create jcr_user login if not exists
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'jcr_user')
BEGIN
    CREATE LOGIN jcr_user WITH PASSWORD = 'password', CHECK_POLICY = OFF;
    PRINT 'Login jcr_user created successfully';
END
ELSE
BEGIN
    PRINT 'Login jcr_user already exists';
END
GO

-- Create user in database if not exists
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'jcr_user')
BEGIN
    CREATE USER jcr_user FOR LOGIN jcr_user;
    PRINT 'User jcr_user created in jackrabbit database';
END
ELSE
BEGIN
    PRINT 'User jcr_user already exists in jackrabbit database';
END
GO

-- Grant permissions
ALTER ROLE db_owner ADD MEMBER jcr_user;
GO

PRINT 'Jackrabbit database setup completed';
GO
