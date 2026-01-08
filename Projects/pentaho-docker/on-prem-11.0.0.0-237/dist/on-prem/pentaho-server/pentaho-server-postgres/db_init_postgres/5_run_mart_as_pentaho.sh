#!/bin/bash
#
# Run Pentaho Operations Mart tables setup as pentaho user
# Per Pentaho Academy installation guide
#
set -e

echo "Running Operations Mart setup as pentaho user..."

PGPASSWORD=password psql -U pentaho -d hibernate -f /docker-entrypoint-initdb.d/_pentaho_mart_tables.sql

echo "Operations Mart setup complete."
