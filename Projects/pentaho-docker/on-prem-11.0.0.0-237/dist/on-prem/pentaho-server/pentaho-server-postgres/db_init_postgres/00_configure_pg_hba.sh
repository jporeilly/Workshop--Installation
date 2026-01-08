#!/bin/bash
#
# Configure pg_hba.conf for Pentaho Server
# This script runs during PostgreSQL container initialization
#

set -e

PG_HBA_PATH="$PGDATA/pg_hba.conf"

echo "Configuring pg_hba.conf for Pentaho Server..."

# Backup original
cp "$PG_HBA_PATH" "${PG_HBA_PATH}.backup"

# Create new pg_hba.conf
cat > "$PG_HBA_PATH" << 'EOF'
# PostgreSQL Client Authentication Configuration File
# Pentaho Server 11 with PostgreSQL 17
#
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             postgres                                scram-sha-256
local   all             all                                     scram-sha-256

# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256

# IPv4 connections from Docker network (allow all for container communication)
host    all             all             0.0.0.0/0               md5

# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256

# Allow replication connections from localhost
local   replication     all                                     scram-sha-256
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
EOF

echo "pg_hba.conf configured successfully."

# Reload PostgreSQL configuration
pg_ctl reload -D "$PGDATA" || true
