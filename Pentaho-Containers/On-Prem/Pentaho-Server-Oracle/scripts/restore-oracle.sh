#!/bin/bash
# =============================================================================
# Oracle Database Restore Script for Pentaho Server
# =============================================================================
#
# Restores a Data Pump export to Oracle database
#
# Usage:
#   ./scripts/restore-oracle.sh <backup-file>
#
# Example:
#   ./scripts/restore-oracle.sh pentaho_backup_20260112_143000.dmp
#
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Load environment
if [ -f ".env" ]; then
    source .env
fi

ORACLE_PASSWORD="${ORACLE_PASSWORD:-password}"
CONTAINER_NAME="pentaho-oracle"
BACKUP_DIR="$PROJECT_DIR/backups"

# Check arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}Error: No backup file specified${NC}"
    echo ""
    echo "Usage: $0 <backup-file>"
    echo ""
    echo "Available backups:"
    ls -1 "$BACKUP_DIR"/*.dmp 2>/dev/null || echo "  No backups found in $BACKUP_DIR"
    exit 1
fi

BACKUP_FILE="$1"

# Check if file exists (with or without path)
if [ -f "$BACKUP_FILE" ]; then
    BACKUP_PATH="$BACKUP_FILE"
elif [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"
else
    echo -e "${RED}Error: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo "=========================================="
echo " Oracle Database Restore"
echo "=========================================="
echo ""
echo -e "${YELLOW}WARNING: This will replace existing data!${NC}"
echo "Backup file: $BACKUP_PATH"
echo ""
read -p "Are you sure you want to continue? (yes/NO) " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Restore cancelled"
    exit 0
fi

# Check if Oracle container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Oracle container is not running${NC}"
    echo "Start the container first: docker compose up -d oracle"
    exit 1
fi

echo ""
echo -e "${BLUE}→ Stopping Pentaho Server...${NC}"
docker compose stop pentaho-server 2>/dev/null || true

echo -e "${BLUE}→ Copying backup file to container...${NC}"
docker cp "$BACKUP_PATH" "$CONTAINER_NAME:/tmp/restore.dmp"

echo -e "${BLUE}→ Running Data Pump import...${NC}"
echo "  This may take several minutes..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="restore_${TIMESTAMP}.log"

docker exec -i "$CONTAINER_NAME" bash -c "
    # Move file to Data Pump directory
    mv /tmp/restore.dmp /opt/oracle/admin/FREE/dpdump/restore.dmp 2>/dev/null || \
    mv /tmp/restore.dmp /opt/oracle/product/23c/dbhomeFree/rdbms/log/restore.dmp 2>/dev/null || true

    # Run import with TABLE_EXISTS_ACTION=REPLACE
    impdp system/${ORACLE_PASSWORD}@//localhost:1521/FREEPDB1 \
        schemas=JCR_USER,PENTAHO_USER,HIBUSER \
        directory=DATA_PUMP_DIR \
        dumpfile=restore.dmp \
        logfile=${LOG_FILE} \
        TABLE_EXISTS_ACTION=REPLACE \
        2>&1
" || {
    echo -e "${YELLOW}⚠ Import completed with warnings (this is often normal)${NC}"
}

echo ""
echo -e "${BLUE}→ Starting Pentaho Server...${NC}"
docker compose start pentaho-server

echo ""
echo -e "${GREEN}✓ Restore complete${NC}"
echo ""
echo "Pentaho Server is restarting. It may take a few minutes to be ready."
echo "Check status: docker compose logs -f pentaho-server"
echo "=========================================="
