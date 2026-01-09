#!/bin/bash
set -e

# Create Pentaho Operations Mart tables in hibernate database
# Uses environment variables: HIBERNATE_DB_USER

echo "Creating pentaho_operations_mart schema and tables..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "hibernate" -f /docker-entrypoint-initdb.d/5_pentaho_mart_postgresql.sql.src

# Grant schema permissions to hibernate user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "hibernate" <<-EOSQL
GRANT USAGE ON SCHEMA pentaho_operations_mart TO ${HIBERNATE_DB_USER};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA pentaho_operations_mart TO ${HIBERNATE_DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA pentaho_operations_mart GRANT ALL ON TABLES TO ${HIBERNATE_DB_USER};
EOSQL

echo "Pentaho Operations Mart tables created in 'hibernate' database"
