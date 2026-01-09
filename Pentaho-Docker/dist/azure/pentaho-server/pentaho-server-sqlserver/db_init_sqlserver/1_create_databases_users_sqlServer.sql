USE master

-- Jackrabbit database and jcr_user creation --
IF EXISTS(select * from sys.databases where name = N'jackrabbit')
DROP DATABASE jackrabbit
GO
CREATE DATABASE jackrabbit
GO

IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = N'jcr_user')
CREATE LOGIN [jcr_user] WITH PASSWORD = N'Password#1'
GO

-- Hibernate database and hibuser creation --
IF EXISTS(select * from sys.databases where name = N'hibernate')
DROP DATABASE hibernate
GO
CREATE DATABASE hibernate
GO
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = N'hibuser')
CREATE LOGIN hibuser WITH PASSWORD = N'Password#1'
GO

-- Quartz database and pentaho_user creation --
IF NOT EXISTS(select * from sys.databases where name = N'quartz')
CREATE DATABASE quartz
GO
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = N'pentaho_user')
CREATE LOGIN pentaho_user WITH PASSWORD = N'Password#1'
GO

-- pentaho_dilogs database and pentaho_user creation --
IF EXISTS(select * from sys.databases where name = N'pentaho_dilogs')
DROP DATABASE pentaho_dilogs
GO
CREATE DATABASE pentaho_dilogs
GO
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = N'dilogs_user')
CREATE LOGIN dilogs_user WITH PASSWORD = N'Password#1'
GO

-- pentaho_operations_mart database and pentaho_user creation --
IF EXISTS(select * from sys.databases where name = N'pentaho_operations_mart')
DROP DATABASE pentaho_operations_mart
GO
CREATE DATABASE pentaho_operations_mart
GO
IF NOT EXISTS 
    (SELECT name  
     FROM master.sys.server_principals
     WHERE name = N'pentaho_operations_mart')
CREATE LOGIN pentaho_operations_mart WITH PASSWORD = N'Password#1'
GO
