#!/bin/bash
# =============================================================================
# Vault Backup Script
# =============================================================================
#
# Creates a backup of Vault data including:
#   - Vault keys (unseal keys and root token)
#   - AppRole credentials
#   - Generated passwords
#
# Usage:
#   ./scripts/backup-vault.sh [backup_dir]
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

# Backup directory
BACKUP_DIR="${1:-$PROJECT_DIR/backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="vault-backup-$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo "=========================================="
echo " Vault Backup"
echo "=========================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_PATH"

echo "→ Creating backup at: $BACKUP_PATH"
echo ""

# Check if Vault container is running
if ! docker compose ps | grep -q "pentaho-vault.*Up"; then
    echo -e "${RED}✗ Vault container is not running${NC}"
    echo "  Start services first: docker compose up -d"
    exit 1
fi

# Backup vault-keys.json (contains unseal keys and root token)
echo "→ Backing up Vault keys..."
if docker exec pentaho-vault test -f /vault/data/vault-keys.json 2>/dev/null; then
    docker cp pentaho-vault:/vault/data/vault-keys.json "$BACKUP_PATH/vault-keys.json"
    chmod 600 "$BACKUP_PATH/vault-keys.json"
    echo -e "${GREEN}✓ vault-keys.json backed up${NC}"
else
    echo -e "${YELLOW}⚠ vault-keys.json not found (Vault may not be initialized)${NC}"
fi

# Backup approle-creds.json
echo "→ Backing up AppRole credentials..."
if docker exec pentaho-vault test -f /vault/data/approle-creds.json 2>/dev/null; then
    docker cp pentaho-vault:/vault/data/approle-creds.json "$BACKUP_PATH/approle-creds.json"
    chmod 600 "$BACKUP_PATH/approle-creds.json"
    echo -e "${GREEN}✓ approle-creds.json backed up${NC}"
else
    echo -e "${YELLOW}⚠ approle-creds.json not found${NC}"
fi

# Backup generated-passwords.json
echo "→ Backing up generated passwords..."
if docker exec pentaho-vault test -f /vault/data/generated-passwords.json 2>/dev/null; then
    docker cp pentaho-vault:/vault/data/generated-passwords.json "$BACKUP_PATH/generated-passwords.json"
    chmod 600 "$BACKUP_PATH/generated-passwords.json"
    echo -e "${GREEN}✓ generated-passwords.json backed up${NC}"
else
    echo -e "${YELLOW}⚠ generated-passwords.json not found${NC}"
fi

# Create a tarball of the backup
echo ""
echo "→ Creating compressed archive..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# Set restrictive permissions on the archive
chmod 600 "$BACKUP_NAME.tar.gz"

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Backup complete!${NC}"
echo "=========================================="
echo ""
echo "Backup location: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo ""
echo "To restore, use: ./scripts/restore-vault.sh $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo ""
echo -e "${RED}WARNING: This backup contains sensitive credentials!${NC}"
echo "Store securely and consider encrypting for long-term storage."
echo "=========================================="
