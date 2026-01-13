#!/bin/bash
#
# Pentaho PostgreSQL Backup Script
# Creates a complete backup of all Pentaho repository databases
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a
    source "$SCRIPT_DIR/../.env"
    set +a
elif [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Backup configuration
BACKUP_DIR="${SCRIPT_DIR}/../backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="pentaho-postgres-backup-${TIMESTAMP}.sql"
CONTAINER_NAME="pentaho-postgres"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo " Pentaho PostgreSQL Backup"
echo "=========================================="
echo "Container: $CONTAINER_NAME"
echo "Backup file: $BACKUP_DIR/$BACKUP_FILE"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}✗ PostgreSQL container '${CONTAINER_NAME}' is not running${NC}"
    exit 1
fi

# Perform backup
echo "Creating backup..."
if docker exec "$CONTAINER_NAME" pg_dumpall -U postgres > "$BACKUP_DIR/$BACKUP_FILE"; then

    # Compress backup
    echo "Compressing backup..."
    gzip "$BACKUP_DIR/$BACKUP_FILE"

    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE.gz" | cut -f1)
    echo -e "${GREEN}✓ Backup completed successfully${NC}"
    echo "  File: $BACKUP_DIR/$BACKUP_FILE.gz"
    echo "  Size: $BACKUP_SIZE"

    # List recent backups
    echo ""
    echo "Recent backups:"
    ls -lht "$BACKUP_DIR" | head -6
else
    echo -e "${RED}✗ Backup failed${NC}"
    exit 1
fi
