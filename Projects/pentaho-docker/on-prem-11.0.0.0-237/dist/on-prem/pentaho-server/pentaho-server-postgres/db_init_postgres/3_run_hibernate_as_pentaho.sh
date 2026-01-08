#!/bin/bash
#
# Run Hibernate database setup as pentaho user
# Per Pentaho Academy installation guide
#
set -e

echo "Running Hibernate setup as pentaho user..."

PGPASSWORD=password psql -U pentaho -d hibernate << 'EOSQL'
-- PostgreSQL 15+ requires explicit schema privileges
GRANT ALL ON SCHEMA public TO hibuser;
GRANT CREATE ON SCHEMA public TO hibuser;

-- Set default privileges for future objects created by pentaho user
ALTER DEFAULT PRIVILEGES FOR ROLE pentaho IN SCHEMA public 
    GRANT ALL ON TABLES TO hibuser;
ALTER DEFAULT PRIVILEGES FOR ROLE pentaho IN SCHEMA public 
    GRANT ALL ON SEQUENCES TO hibuser;
ALTER DEFAULT PRIVILEGES FOR ROLE pentaho IN SCHEMA public 
    GRANT ALL ON FUNCTIONS TO hibuser;

-- Grant ownership of public schema to hibuser
ALTER SCHEMA public OWNER TO hibuser;
EOSQL

echo "Hibernate setup complete."
