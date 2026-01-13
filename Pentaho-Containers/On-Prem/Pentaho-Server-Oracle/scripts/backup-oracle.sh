#!/bin/bash
# =============================================================================
# Oracle Database Backup Script for Pentaho Server
# =============================================================================
#
# Creates a Data Pump export of all Pentaho schemas in Oracle
#
# Usage:
#   ./scripts/backup-oracle.sh
#
# Output:
#   backups/pentaho_backup_YYYYMMDD_HHMMSS.dmp
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
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="pentaho_backup_${TIMESTAMP}.dmp"
LOG_FILE="pentaho_backup_${TIMESTAMP}.log"

echo "=========================================="
echo " Oracle Database Backup"
echo "=========================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if Oracle container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Oracle container is not running${NC}"
    echo "Start the container first: docker compose up -d oracle"
    exit 1
fi

echo -e "${BLUE}→ Creating Data Pump export...${NC}"
echo "  This may take a few minutes depending on data size..."

# Create Data Pump export of all Pentaho schemas
docker exec -i "$CONTAINER_NAME" bash -c "
    expdp system/${ORACLE_PASSWORD}@//localhost:1521/FREEPDB1 \
        schemas=JCR_USER,PENTAHO_USER,HIBUSER \
        directory=DATA_PUMP_DIR \
        dumpfile=${BACKUP_FILE} \
        logfile=${LOG_FILE} \
        2>&1
" || {
    echo -e "${RED}✗ Data Pump export failed${NC}"
    exit 1
}

# Copy backup file from container
echo -e "${BLUE}→ Copying backup file...${NC}"
docker cp "$CONTAINER_NAME:/opt/oracle/admin/FREE/dpdump/${BACKUP_FILE}" "$BACKUP_DIR/" 2>/dev/null || \
docker cp "$CONTAINER_NAME:/opt/oracle/product/23c/dbhomeFree/rdbms/log/${BACKUP_FILE}" "$BACKUP_DIR/" 2>/dev/null || {
    # Try alternate location
    docker exec "$CONTAINER_NAME" find /opt/oracle -name "${BACKUP_FILE}" -exec cat {} \; > "$BACKUP_DIR/$BACKUP_FILE" 2>/dev/null
}

# Get backup size
if [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_FILE" | cut -f1)
    echo ""
    echo -e "${GREEN}✓ Backup complete${NC}"
    echo ""
    echo "Backup details:"
    echo "  File: $BACKUP_DIR/$BACKUP_FILE"
    echo "  Size: $BACKUP_SIZE"
    echo ""
    echo "To restore this backup, run:"
    echo "  ./scripts/restore-oracle.sh $BACKUP_FILE"
else
    echo -e "${YELLOW}⚠ Backup file created in container but could not be copied${NC}"
    echo "  Check container for: ${BACKUP_FILE}"
fi

echo "=========================================="
