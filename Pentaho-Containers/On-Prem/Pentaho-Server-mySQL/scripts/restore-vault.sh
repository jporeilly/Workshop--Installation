#!/bin/bash
# =============================================================================
# Vault Restore Script
# =============================================================================
#
# Restores Vault data from a backup created by backup-vault.sh
#
# Usage:
#   ./scripts/restore-vault.sh <backup_file.tar.gz>
#
# WARNING: This will overwrite existing Vault credentials!
#
# =============================================================================

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    echo ""
    echo "Example: $0 backups/vault-backup-20260116-120000.tar.gz"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}✗ Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

echo "=========================================="
echo " Vault Restore"
echo "=========================================="
echo ""
echo -e "${YELLOW}WARNING: This will overwrite existing Vault credentials!${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""

# Check if Vault container is running
if ! docker compose ps | grep -q "pentaho-vault.*Up"; then
    echo -e "${RED}✗ Vault container is not running${NC}"
    echo "  Start services first: docker compose up -d vault"
    exit 1
fi

# Create temporary extraction directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "→ Extracting backup..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find the extracted directory
BACKUP_DIR=$(ls -d "$TEMP_DIR"/vault-backup-* 2>/dev/null | head -1)
if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}✗ Invalid backup archive - no vault-backup directory found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Backup extracted${NC}"
echo ""

# Restore vault-keys.json
echo "→ Restoring Vault keys..."
if [ -f "$BACKUP_DIR/vault-keys.json" ]; then
    docker cp "$BACKUP_DIR/vault-keys.json" pentaho-vault:/vault/data/vault-keys.json
    docker exec pentaho-vault chmod 600 /vault/data/vault-keys.json
    docker exec pentaho-vault chown vault:vault /vault/data/vault-keys.json 2>/dev/null || true
    echo -e "${GREEN}✓ vault-keys.json restored${NC}"
else
    echo -e "${YELLOW}⚠ vault-keys.json not in backup${NC}"
fi

# Restore approle-creds.json
echo "→ Restoring AppRole credentials..."
if [ -f "$BACKUP_DIR/approle-creds.json" ]; then
    docker cp "$BACKUP_DIR/approle-creds.json" pentaho-vault:/vault/data/approle-creds.json
    docker exec pentaho-vault chmod 600 /vault/data/approle-creds.json
    docker exec pentaho-vault chown vault:vault /vault/data/approle-creds.json 2>/dev/null || true
    echo -e "${GREEN}✓ approle-creds.json restored${NC}"
else
    echo -e "${YELLOW}⚠ approle-creds.json not in backup${NC}"
fi

# Restore generated-passwords.json
echo "→ Restoring generated passwords..."
if [ -f "$BACKUP_DIR/generated-passwords.json" ]; then
    docker cp "$BACKUP_DIR/generated-passwords.json" pentaho-vault:/vault/data/generated-passwords.json
    docker exec pentaho-vault chmod 600 /vault/data/generated-passwords.json
    docker exec pentaho-vault chown vault:vault /vault/data/generated-passwords.json 2>/dev/null || true
    echo -e "${GREEN}✓ generated-passwords.json restored${NC}"
else
    echo -e "${YELLOW}⚠ generated-passwords.json not in backup${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Restore complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Restart Vault to apply changes: docker compose restart vault"
echo "  2. Run vault-init to unseal: docker compose up vault-init"
echo "  3. Validate deployment: ./scripts/validate-deployment.sh"
echo "=========================================="
