--
-- Pentaho Jackrabbit (JCR) Database Setup
-- PostgreSQL 17 compatible - schema permissions only
-- User/Database created by 0_init_pentaho_databases.sql
--

\connect jackrabbit

-- PostgreSQL 15+ requires explicit schema privileges
GRANT ALL ON SCHEMA public TO jcr_user;
GRANT CREATE ON SCHEMA public TO jcr_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public 
    GRANT ALL ON TABLES TO jcr_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public 
    GRANT ALL ON SEQUENCES TO jcr_user;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public 
    GRANT ALL ON FUNCTIONS TO jcr_user;

-- Grant ownership of public schema to jcr_user
ALTER SCHEMA public OWNER TO jcr_user;
