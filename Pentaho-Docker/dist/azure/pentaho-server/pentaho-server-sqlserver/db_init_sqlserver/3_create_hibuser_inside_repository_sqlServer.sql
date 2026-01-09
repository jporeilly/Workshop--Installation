-- Create hibuser user inside Hibernate repository

CREATE USER hibuser FOR LOGIN hibuser
EXEC sp_addrolemember N'db_owner', N'hibuser'
GO

--End--
