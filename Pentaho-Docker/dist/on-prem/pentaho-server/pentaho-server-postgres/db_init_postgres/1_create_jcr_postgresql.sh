#!/bin/bash
set -e

# Create JCR (Jackrabbit) database and user
# Uses environment variables: JCR_DB_USER, JCR_DB_PASSWORD

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    DROP DATABASE IF EXISTS jackrabbit;
    DROP USER IF EXISTS ${JCR_DB_USER};
    
    CREATE USER ${JCR_DB_USER} PASSWORD '${JCR_DB_PASSWORD}';
    
    CREATE DATABASE jackrabbit WITH OWNER = ${JCR_DB_USER} ENCODING = 'UTF8' TABLESPACE = pg_default;
    
    GRANT ALL PRIVILEGES ON DATABASE jackrabbit TO ${JCR_DB_USER};
EOSQL

echo "JCR database 'jackrabbit' created with user '${JCR_DB_USER}'"
