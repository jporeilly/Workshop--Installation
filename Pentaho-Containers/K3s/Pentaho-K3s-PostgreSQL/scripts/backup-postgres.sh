#!/bin/bash
# =============================================================================
# PostgreSQL Backup Script for K3s
# =============================================================================
# Creates a backup of all Pentaho databases
#
# Usage: ./scripts/backup-postgres.sh
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
NAMESPACE="pentaho"
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/pentaho-postgres-backup-${TIMESTAMP}.sql"

echo -e "${YELLOW}PostgreSQL Backup for K3s${NC}"
echo "=========================="

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Check if postgres pod is running
if ! kubectl get pod -l app=postgres -n ${NAMESPACE} | grep -q Running; then
    echo -e "${RED}ERROR: PostgreSQL pod is not running${NC}"
    exit 1
fi

# Get postgres pod name
POD_NAME=$(kubectl get pod -l app=postgres -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')

echo "Backing up from pod: ${POD_NAME}"
echo "Backup file: ${BACKUP_FILE}"
echo ""

# Create backup
echo -e "${YELLOW}Creating backup...${NC}"
kubectl exec ${POD_NAME} -n ${NAMESPACE} -- \
    pg_dumpall -U postgres > "${BACKUP_FILE}"

# Compress backup
echo -e "${YELLOW}Compressing backup...${NC}"
gzip "${BACKUP_FILE}"
BACKUP_FILE="${BACKUP_FILE}.gz"

# Show result
BACKUP_SIZE=$(ls -lh "${BACKUP_FILE}" | awk '{print $5}')
echo ""
echo -e "${GREEN}Backup complete!${NC}"
echo "File: ${BACKUP_FILE}"
echo "Size: ${BACKUP_SIZE}"
echo ""

# List recent backups
echo "Recent backups:"
ls -lht "${BACKUP_DIR}"/*.gz 2>/dev/null | head -5
