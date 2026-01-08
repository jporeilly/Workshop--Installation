--
-- Pentaho Jackrabbit (JCR) Database Setup
-- PostgreSQL 17 - jcr_user is owner
--

\connect jackrabbit

-- Grant schema permissions
GRANT ALL ON SCHEMA public TO jcr_user;
GRANT CREATE ON SCHEMA public TO jcr_user;
ALTER SCHEMA public OWNER TO jcr_user;

-- Set default privileges for objects created by jcr_user
ALTER DEFAULT PRIVILEGES FOR ROLE jcr_user IN SCHEMA public 
    GRANT ALL ON TABLES TO jcr_user;
ALTER DEFAULT PRIVILEGES FOR ROLE jcr_user IN SCHEMA public 
    GRANT ALL ON SEQUENCES TO jcr_user;
ALTER DEFAULT PRIVILEGES FOR ROLE jcr_user IN SCHEMA public 
    GRANT ALL ON FUNCTIONS TO jcr_user;
