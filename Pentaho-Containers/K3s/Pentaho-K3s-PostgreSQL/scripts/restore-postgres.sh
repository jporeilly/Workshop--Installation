#!/bin/bash
# =============================================================================
# PostgreSQL Restore Script for K3s
# =============================================================================
# Restores Pentaho databases from a backup file
#
# Usage: ./scripts/restore-postgres.sh <backup-file.sql.gz>
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
NAMESPACE="pentaho"

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <backup-file.sql.gz>"
    echo ""
    echo "Available backups:"
    ls -lht "$(dirname "$0")/../backups"/*.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# Check if file exists
if [ ! -f "${BACKUP_FILE}" ]; then
    echo -e "${RED}ERROR: Backup file not found: ${BACKUP_FILE}${NC}"
    exit 1
fi

echo -e "${YELLOW}PostgreSQL Restore for K3s${NC}"
echo "==========================="
echo "Backup file: ${BACKUP_FILE}"
echo ""

# Warning
echo -e "${RED}WARNING: This will overwrite existing databases!${NC}"
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Check if postgres pod is running
if ! kubectl get pod -l app=postgres -n ${NAMESPACE} | grep -q Running; then
    echo -e "${RED}ERROR: PostgreSQL pod is not running${NC}"
    exit 1
fi

# Get postgres pod name
POD_NAME=$(kubectl get pod -l app=postgres -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "Restoring to pod: ${POD_NAME}"

# Decompress and restore
echo -e "${YELLOW}Restoring database...${NC}"
if [[ "${BACKUP_FILE}" == *.gz ]]; then
    gunzip -c "${BACKUP_FILE}" | kubectl exec -i ${POD_NAME} -n ${NAMESPACE} -- psql -U postgres
else
    kubectl exec -i ${POD_NAME} -n ${NAMESPACE} -- psql -U postgres < "${BACKUP_FILE}"
fi

echo ""
echo -e "${GREEN}Restore complete!${NC}"
echo ""
echo "You may need to restart Pentaho Server:"
echo "  kubectl rollout restart deployment/pentaho-server -n pentaho"
