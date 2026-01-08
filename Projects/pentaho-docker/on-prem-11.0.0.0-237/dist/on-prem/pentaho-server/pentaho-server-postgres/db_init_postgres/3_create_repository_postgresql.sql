--
-- Pentaho Hibernate Repository Database Setup
-- PostgreSQL 17 compatible - schema permissions only
-- User/Database created by 0_init_pentaho_databases.sql
--

\connect hibernate

-- PostgreSQL 15+ requires explicit schema privileges
GRANT ALL ON SCHEMA public TO hibuser;
GRANT CREATE ON SCHEMA public TO hibuser;
ALTER SCHEMA public OWNER TO hibuser;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public 
    GRANT ALL ON TABLES TO hibuser;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public 
    GRANT ALL ON SEQUENCES TO hibuser;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public 
    GRANT ALL ON FUNCTIONS TO hibuser;
