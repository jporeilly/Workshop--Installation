#!/bin/bash
#
# Run JCR database setup as pentaho user
# Per Pentaho Academy installation guide
#
set -e

echo "Running JCR setup as pentaho user..."

PGPASSWORD=password psql -U pentaho -d jackrabbit << 'EOSQL'
-- PostgreSQL 15+ requires explicit schema privileges
GRANT ALL ON SCHEMA public TO jcr_user;
GRANT CREATE ON SCHEMA public TO jcr_user;

-- Set default privileges for future objects created by pentaho user
ALTER DEFAULT PRIVILEGES FOR ROLE pentaho IN SCHEMA public 
    GRANT ALL ON TABLES TO jcr_user;
ALTER DEFAULT PRIVILEGES FOR ROLE pentaho IN SCHEMA public 
    GRANT ALL ON SEQUENCES TO jcr_user;
ALTER DEFAULT PRIVILEGES FOR ROLE pentaho IN SCHEMA public 
    GRANT ALL ON FUNCTIONS TO jcr_user;

-- Grant ownership of public schema to jcr_user
ALTER SCHEMA public OWNER TO jcr_user;
EOSQL

echo "JCR setup complete."
