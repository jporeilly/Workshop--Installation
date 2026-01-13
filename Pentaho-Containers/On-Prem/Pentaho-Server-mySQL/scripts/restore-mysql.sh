#!/bin/bash
#
# Pentaho MySQL Restore Script
# Restores Pentaho repository databases from backup
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load environment variables
if [ -f "../.env" ]; then
    set -a
    source ../.env
    set +a
elif [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# Configuration
CONTAINER_NAME="pentaho-mysql"
MYSQL_PASSWORD="${MYSQL_ROOT_PASSWORD:-password}"

# Check arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup-file.sql|backup-file.sql.gz>"
    echo ""
    echo "Available backups:"
    ls -lht backups/ 2>/dev/null | head -10 || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}✗ Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo "=========================================="
echo " Pentaho MySQL Restore"
echo "=========================================="
echo "Container: $CONTAINER_NAME"
echo "Backup file: $BACKUP_FILE"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}✗ MySQL container '${CONTAINER_NAME}' is not running${NC}"
    echo "Start the container with: docker compose up -d mysql"
    exit 1
fi

# Warning
echo -e "${YELLOW}WARNING: This will overwrite existing Pentaho repository data!${NC}"
read -p "Are you sure you want to continue? (yes/NO) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled"
    exit 0
fi

# Decompress if needed
TEMP_FILE=""
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo "Decompressing backup..."
    TEMP_FILE=$(mktemp)
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
    RESTORE_FILE="$TEMP_FILE"
else
    RESTORE_FILE="$BACKUP_FILE"
fi

# Perform restore
echo "Restoring database..."
if docker exec -i "$CONTAINER_NAME" mysql \
    -uroot \
    -p"$MYSQL_PASSWORD" \
    < "$RESTORE_FILE"; then

    echo -e "${GREEN}✓ Database restored successfully${NC}"
else
    echo -e "${RED}✗ Restore failed${NC}"
    [ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
    exit 1
fi

# Cleanup
[ -n "$TEMP_FILE" ] && rm -f "$TEMP_FILE"

echo ""
echo -e "${YELLOW}⚠ Restart Pentaho Server to apply changes:${NC}"
echo "  docker compose restart pentaho-server"
