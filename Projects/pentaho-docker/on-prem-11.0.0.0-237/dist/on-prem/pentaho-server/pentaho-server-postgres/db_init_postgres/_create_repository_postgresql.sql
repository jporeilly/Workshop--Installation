--
-- Pentaho Hibernate Repository Database Setup
-- PostgreSQL 17 - hibuser is owner
--

\connect hibernate

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO hibuser;
GRANT CREATE ON SCHEMA public TO hibuser;
ALTER SCHEMA public OWNER TO hibuser;

-- Set default privileges for objects created by hibuser
ALTER DEFAULT PRIVILEGES FOR ROLE hibuser IN SCHEMA public 
    GRANT ALL ON TABLES TO hibuser;
ALTER DEFAULT PRIVILEGES FOR ROLE hibuser IN SCHEMA public 
    GRANT ALL ON SEQUENCES TO hibuser;
ALTER DEFAULT PRIVILEGES FOR ROLE hibuser IN SCHEMA public 
    GRANT ALL ON FUNCTIONS TO hibuser;

-- Grant hibuser permission to create schemas (for pentaho_dilogs and pentaho_operations_mart)
GRANT CREATE ON DATABASE hibernate TO hibuser;
