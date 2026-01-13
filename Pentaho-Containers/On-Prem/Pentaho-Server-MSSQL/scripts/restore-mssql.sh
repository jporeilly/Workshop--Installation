#!/bin/bash
#
# Pentaho SQL Server Restore Script
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
CONTAINER_NAME="pentaho-mssql"
MSSQL_PASSWORD="${MSSQL_SA_PASSWORD:-Password123!}"

# Check arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup-file.tar.gz>"
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
echo " Pentaho SQL Server Restore"
echo "=========================================="
echo "Container: $CONTAINER_NAME"
echo "Backup file: $BACKUP_FILE"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}✗ SQL Server container '${CONTAINER_NAME}' is not running${NC}"
    echo "Start the container with: docker compose up -d mssql"
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

# Extract archive to temp directory
TEMP_DIR=$(mktemp -d)
echo "Extracting backup archive..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find the .bak files
JACKRABBIT_BAK=$(find "$TEMP_DIR" -name "jackrabbit-*.bak" | head -1)
QUARTZ_BAK=$(find "$TEMP_DIR" -name "quartz-*.bak" | head -1)
HIBERNATE_BAK=$(find "$TEMP_DIR" -name "hibernate-*.bak" | head -1)

if [ -z "$JACKRABBIT_BAK" ] || [ -z "$QUARTZ_BAK" ] || [ -z "$HIBERNATE_BAK" ]; then
    echo -e "${RED}✗ Could not find all required backup files in archive${NC}"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Databases to restore
declare -A BACKUP_FILES
BACKUP_FILES["jackrabbit"]="$JACKRABBIT_BAK"
BACKUP_FILES["quartz"]="$QUARTZ_BAK"
BACKUP_FILES["hibernate"]="$HIBERNATE_BAK"

# Perform restore for each database
for DB in "${!BACKUP_FILES[@]}"; do
    BAK_FILE="${BACKUP_FILES[$DB]}"
    BAK_FILENAME=$(basename "$BAK_FILE")

    echo "Restoring database: $DB from $BAK_FILENAME..."

    # Copy backup file to container
    docker cp "$BAK_FILE" "$CONTAINER_NAME:/var/opt/mssql/backup/${BAK_FILENAME}"

    # Set database to single user mode and restore
    docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_PASSWORD" -C \
        -Q "ALTER DATABASE [$DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
            RESTORE DATABASE [$DB] FROM DISK = N'/var/opt/mssql/backup/${BAK_FILENAME}' WITH REPLACE, STATS = 10;
            ALTER DATABASE [$DB] SET MULTI_USER;" &> /dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $DB database restored successfully${NC}"
    else
        echo -e "${RED}✗ Restore failed for $DB${NC}"
        # Try to set back to multi-user mode
        docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_PASSWORD" -C \
            -Q "ALTER DATABASE [$DB] SET MULTI_USER;" &> /dev/null || true
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Remove backup from container
    docker exec "$CONTAINER_NAME" rm -f "/var/opt/mssql/backup/${BAK_FILENAME}"
    echo ""
done

# Cleanup
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✓ All databases restored successfully${NC}"
echo ""
echo -e "${YELLOW}⚠ Restart Pentaho Server to apply changes:${NC}"
echo "  docker compose restart pentaho-server"
