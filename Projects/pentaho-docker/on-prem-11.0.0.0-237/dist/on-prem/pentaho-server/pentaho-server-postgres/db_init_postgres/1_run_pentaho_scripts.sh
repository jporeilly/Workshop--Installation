#!/bin/bash
#
# Execute Pentaho database scripts as pentaho superuser using \i
# Per Pentaho Academy installation guide - archive deployment workflow
#
set -e

SCRIPT_DIR=/docker-entrypoint-initdb.d

echo "=========================================="
echo "Session 1: JCR and Quartz setup"
echo "=========================================="
PGPASSWORD=password psql -U pentaho -d postgres << EOSQL
\i $SCRIPT_DIR/_create_jcr_postgresql.sql
\i $SCRIPT_DIR/_create_quartz_postgresql.sql
EOSQL

echo "=========================================="
echo "Session 2: Repository and Mart setup"
echo "=========================================="
PGPASSWORD=password psql -U pentaho -d postgres << EOSQL
\i $SCRIPT_DIR/_create_repository_postgresql.sql
\i $SCRIPT_DIR/_pentaho_mart_tables.sql
EOSQL

echo "=========================================="
echo "Session 3: Logging tables setup"
echo "=========================================="
PGPASSWORD=password psql -U pentaho -d postgres << EOSQL
\i $SCRIPT_DIR/_create_dilogs_postgresql.sql
EOSQL

echo "=========================================="
echo "Pentaho database setup complete!"
echo "=========================================="
