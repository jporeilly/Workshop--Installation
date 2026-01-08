#!/bin/bash
#
# Execute Pentaho database scripts as pentaho superuser
# Per Pentaho Academy installation guide - archive deployment workflow
#
set -e

SCRIPT_DIR=/docker-entrypoint-initdb.d

echo "=========================================="
echo "Session 1: JCR setup"
echo "=========================================="
PGPASSWORD=password psql -U pentaho -d postgres -f "$SCRIPT_DIR/_create_jcr_postgresql.sql"

echo "=========================================="
echo "Session 2: Quartz setup"
echo "=========================================="
PGPASSWORD=password psql -U pentaho -d postgres -f "$SCRIPT_DIR/_create_quartz_postgresql.sql"

echo "=========================================="
echo "Session 3: Repository setup"
echo "=========================================="
PGPASSWORD=password psql -U pentaho -d postgres -f "$SCRIPT_DIR/_create_repository_postgresql.sql"

echo "=========================================="
echo "Session 4: Operations Mart setup"
echo "=========================================="
PGPASSWORD=password psql -U pentaho -d postgres -f "$SCRIPT_DIR/_pentaho_mart_tables.sql"

echo "=========================================="
echo "Session 5: Logging tables setup"
echo "=========================================="
PGPASSWORD=password psql -U pentaho -d postgres -f "$SCRIPT_DIR/_create_dilogs_postgresql.sql"

echo "=========================================="
echo "Pentaho database setup complete!"
echo "=========================================="
