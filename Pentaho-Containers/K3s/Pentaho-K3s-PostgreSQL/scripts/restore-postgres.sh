#!/bin/bash
# =============================================================================
# PostgreSQL Restore Script for K3s
# =============================================================================
# Restores Pentaho databases from a backup file created by backup-postgres.sh
#
# This script:
#   - Accepts both compressed (.gz) and uncompressed (.sql) backup files
#   - Overwrites existing databases with backup data
#   - Restores all database objects, users, and permissions
#   - Provides safety confirmation before proceeding
#
# Usage: ./scripts/restore-postgres.sh <backup-file.sql.gz>
#
# Examples:
#   ./scripts/restore-postgres.sh backups/pentaho-postgres-backup-20260126-143022.sql.gz
#   ./scripts/restore-postgres.sh /path/to/backup.sql
#
# Prerequisites:
#   - kubectl configured with access to the cluster
#   - PostgreSQL pod must be running in the pentaho namespace
#   - Valid backup file created by backup-postgres.sh or pg_dumpall
#
# Important Notes:
#   - This operation OVERWRITES existing databases
#   - All current data will be replaced with backup data
#   - You should restart Pentaho Server after restore to ensure consistency
#   - Consider stopping Pentaho Server before restore to prevent write conflicts
#
# Exit codes:
#   0 - Restore completed successfully
#   1 - Error occurred or user cancelled operation
# =============================================================================

set -e  # Exit immediately if any command fails

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Configuration
NAMESPACE="pentaho"  # Kubernetes namespace where PostgreSQL is deployed

# -----------------------------------------------------------------------------
# Check Command Line Arguments
# -----------------------------------------------------------------------------
# Requires a backup file path as the first argument
# If not provided, displays usage information and lists available backups
if [ -z "$1" ]; then
    echo "Usage: $0 <backup-file.sql.gz>"
    echo ""
    echo "Available backups:"
    ls -lht "$(dirname "$0")/../backups"/*.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"

# -----------------------------------------------------------------------------
# Verify Backup File Exists
# -----------------------------------------------------------------------------
# Checks that the specified backup file exists and is accessible
if [ ! -f "${BACKUP_FILE}" ]; then
    echo -e "${RED}ERROR: Backup file not found: ${BACKUP_FILE}${NC}"
    exit 1
fi

echo -e "${YELLOW}PostgreSQL Restore for K3s${NC}"
echo "==========================="
echo "Backup file: ${BACKUP_FILE}"
echo ""

# -----------------------------------------------------------------------------
# Safety Confirmation
# -----------------------------------------------------------------------------
# Displays warning and requires explicit user confirmation
# This prevents accidental data loss from unintended restore operations
echo -e "${RED}WARNING: This will overwrite existing databases!${NC}"
echo "This operation will:"
echo "  - Drop and recreate all Pentaho databases (jackrabbit, quartz, hibernate)"
echo "  - Replace all data with the contents of the backup file"
echo "  - Reset database users and permissions to the backup state"
echo ""
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# -----------------------------------------------------------------------------
# Verify PostgreSQL Pod is Running
# -----------------------------------------------------------------------------
# Checks that the PostgreSQL pod is in "Running" state
# If the pod is not running, the restore cannot proceed
if ! kubectl get pod -l app=postgres -n ${NAMESPACE} | grep -q Running; then
    echo -e "${RED}ERROR: PostgreSQL pod is not running${NC}"
    exit 1
fi

# -----------------------------------------------------------------------------
# Get PostgreSQL Pod Name
# -----------------------------------------------------------------------------
# Dynamically retrieves the pod name using label selector
# This works even if the pod name changes (e.g., after recreation)
POD_NAME=$(kubectl get pod -l app=postgres -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "Restoring to pod: ${POD_NAME}"

# -----------------------------------------------------------------------------
# Restore Database from Backup
# -----------------------------------------------------------------------------
# Handles both compressed (.gz) and uncompressed (.sql) backup files
#
# For compressed files:
#   - Decompresses on-the-fly using gunzip
#   - Pipes SQL commands directly to psql inside the PostgreSQL pod
#
# For uncompressed files:
#   - Streams SQL file directly to psql
#
# The restore process:
#   1. Executes all SQL statements from the backup file
#   2. Recreates databases, tables, and data
#   3. Restores users, roles, and permissions
#   4. Rebuilds indexes and constraints
echo ""
echo -e "${YELLOW}Restoring database...${NC}"
echo "This may take several minutes depending on backup size..."
echo ""

if [[ "${BACKUP_FILE}" == *.gz ]]; then
    # Decompress and pipe to PostgreSQL
    gunzip -c "${BACKUP_FILE}" | kubectl exec -i ${POD_NAME} -n ${NAMESPACE} -- psql -U postgres
else
    # Stream uncompressed SQL file to PostgreSQL
    kubectl exec -i ${POD_NAME} -n ${NAMESPACE} -- psql -U postgres < "${BACKUP_FILE}"
fi

# -----------------------------------------------------------------------------
# Display Completion Message
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}Restore complete!${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Restart Pentaho Server to ensure it uses the restored data:"
echo "   kubectl rollout restart deployment/pentaho-server -n pentaho"
echo ""
echo "2. Monitor the restart:"
echo "   kubectl rollout status deployment/pentaho-server -n pentaho"
echo ""
echo "3. Verify Pentaho Server is working correctly:"
echo "   kubectl logs -f deployment/pentaho-server -n pentaho"
echo ""
echo "4. Check database connectivity:"
echo "   ./scripts/validate-deployment.sh"
