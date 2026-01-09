-- Create jcr_user inside Jackrabbit database

CREATE USER jcr_user FOR LOGIN jcr_user
EXEC sp_addrolemember N'db_owner', N'jcr_user'
GO
