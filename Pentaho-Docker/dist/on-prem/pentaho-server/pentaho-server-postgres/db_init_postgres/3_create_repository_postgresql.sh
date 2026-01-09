#!/bin/bash
set -e

# Create Hibernate repository database and user
# Uses environment variables: HIBERNATE_DB_USER, HIBERNATE_DB_PASSWORD

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    DROP DATABASE IF EXISTS hibernate;
    DROP USER IF EXISTS ${HIBERNATE_DB_USER};
    
    CREATE USER ${HIBERNATE_DB_USER} PASSWORD '${HIBERNATE_DB_PASSWORD}';
    
    CREATE DATABASE hibernate WITH OWNER = ${HIBERNATE_DB_USER} ENCODING = 'UTF8' TABLESPACE = pg_default;
    
    GRANT ALL PRIVILEGES ON DATABASE hibernate TO ${HIBERNATE_DB_USER};
EOSQL

echo "Hibernate database 'hibernate' created with user '${HIBERNATE_DB_USER}'"
