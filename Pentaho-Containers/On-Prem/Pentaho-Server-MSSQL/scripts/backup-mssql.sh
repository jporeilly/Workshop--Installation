#!/bin/bash
#
# Pentaho SQL Server Backup Script
# Creates a complete backup of all Pentaho repository databases
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
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

# Backup configuration
BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
CONTAINER_NAME="pentaho-mssql"
MSSQL_PASSWORD="${MSSQL_SA_PASSWORD:-Password123!}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "=========================================="
echo " Pentaho SQL Server Backup"
echo "=========================================="
echo "Container: $CONTAINER_NAME"
echo "Timestamp: $TIMESTAMP"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}✗ SQL Server container '${CONTAINER_NAME}' is not running${NC}"
    exit 1
fi

# Databases to backup
DATABASES=("jackrabbit" "quartz" "hibernate")

# Perform backups for each database
for DB in "${DATABASES[@]}"; do
    echo "Backing up database: $DB..."
    BACKUP_FILE="${DB}-${TIMESTAMP}.bak"

    # Create backup inside the container
    if docker exec "$CONTAINER_NAME" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_PASSWORD" -C \
        -Q "BACKUP DATABASE [$DB] TO DISK = N'/var/opt/mssql/backup/${BACKUP_FILE}' WITH NOFORMAT, NOINIT, NAME = '${DB}-full', SKIP, NOREWIND, NOUNLOAD, STATS = 10" &> /dev/null; then

        # Copy backup from container to host
        docker cp "$CONTAINER_NAME:/var/opt/mssql/backup/${BACKUP_FILE}" "$BACKUP_DIR/${BACKUP_FILE}"

        # Remove backup from container
        docker exec "$CONTAINER_NAME" rm -f "/var/opt/mssql/backup/${BACKUP_FILE}"

        BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
        echo -e "${GREEN}✓ $DB backup completed${NC}"
        echo "  File: $BACKUP_DIR/$BACKUP_FILE"
        echo "  Size: $BACKUP_SIZE"
    else
        echo -e "${RED}✗ Backup failed for $DB${NC}"
        exit 1
    fi
    echo ""
done

# Create a combined archive
echo "Creating combined archive..."
ARCHIVE_FILE="pentaho-mssql-backup-${TIMESTAMP}.tar.gz"
tar -czf "$BACKUP_DIR/$ARCHIVE_FILE" -C "$BACKUP_DIR" \
    "jackrabbit-${TIMESTAMP}.bak" \
    "quartz-${TIMESTAMP}.bak" \
    "hibernate-${TIMESTAMP}.bak"

# Remove individual backup files
rm -f "$BACKUP_DIR/jackrabbit-${TIMESTAMP}.bak" \
      "$BACKUP_DIR/quartz-${TIMESTAMP}.bak" \
      "$BACKUP_DIR/hibernate-${TIMESTAMP}.bak"

ARCHIVE_SIZE=$(du -h "$BACKUP_DIR/$ARCHIVE_FILE" | cut -f1)
echo -e "${GREEN}✓ Combined archive created${NC}"
echo "  File: $BACKUP_DIR/$ARCHIVE_FILE"
echo "  Size: $ARCHIVE_SIZE"

# List recent backups
echo ""
echo "Recent backups:"
ls -lht "$BACKUP_DIR" | head -6
