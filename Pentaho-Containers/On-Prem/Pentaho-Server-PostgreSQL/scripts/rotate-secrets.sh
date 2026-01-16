#!/bin/bash
# =============================================================================
# Pentaho Secret Rotation Script
# =============================================================================
# Deployment: Pentaho Server with PostgreSQL
#
# PURPOSE:
#   Securely rotates database passwords for all Pentaho service accounts.
#   This script updates passwords in both the database and Vault simultaneously
#   to maintain consistency.
#
# WHEN TO USE:
#   1. After initial deployment (to replace default passwords)
#   2. According to your rotation policy (recommended: every 90 days)
#   3. After a potential security breach
#   4. When onboarding/offboarding team members with database access
#
# WHAT IT DOES:
#   1. Validates prerequisites (PostgreSQL running, Vault unsealed)
#   2. Generates cryptographically secure passwords
#   3. Updates PostgreSQL users with new passwords
#   4. Updates Vault secrets with new passwords
#   5. Saves passwords to generated-passwords.json for recovery
#   6. Restarts Pentaho to pick up new credentials
#
# ROTATION FLOW:
#   ┌─────────────────────────────────────────────────────────────────┐
#   │  1. Generate new passwords                                       │
#   │                    ↓                                             │
#   │  2. Update PostgreSQL users (ALTER USER)                         │
#   │                    ↓                                             │
#   │  3. Update Vault secrets (creates new version)                   │
#   │                    ↓                                             │
#   │  4. Save to generated-passwords.json (for vault-init.sh)         │
#   │                    ↓                                             │
#   │  5. Restart Pentaho (fetches new creds from Vault)               │
#   └─────────────────────────────────────────────────────────────────┘
#
# USAGE:
#   ./scripts/rotate-secrets.sh [options]
#
# OPTIONS:
#   --dry-run     Show what would be done without making changes
#   --no-restart  Update passwords but don't restart Pentaho
#   --user USER   Only rotate password for specific user
#                 (jcr_user, pentaho_user, hibuser)
#   --help        Show this help message
#
# PASSWORD POLICY:
#   - Length: 24 characters
#   - Format: [20 random alphanumeric chars] + "Aa1!"
#   - Generated using /dev/urandom for cryptographic randomness
#
# RECOVERY:
#   If rotation fails partway through:
#   1. Check which component failed (PostgreSQL or Vault)
#   2. The generated-passwords.json contains the new passwords
#   3. You can manually re-run the failed step
#   4. If Pentaho can't connect:
#      - Check Vault secrets match PostgreSQL passwords
#      - Restart Pentaho: docker compose restart pentaho-server
#
# FILES MODIFIED:
#   /vault/data/generated-passwords.json  - Updated with new passwords
#   Vault: secret/data/pentaho/postgresql - Updated with new passwords
#   PostgreSQL: users for all accounts    - Passwords updated
#
# =============================================================================

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Configuration
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-password}"
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_PORT="${VAULT_PORT:-8200}"
VAULT_SECRET_PATH="secret/data/pentaho/postgresql"

# Options
DRY_RUN=false
NO_RESTART=false
SPECIFIC_USER=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-restart)
            NO_RESTART=true
            shift
            ;;
        --user)
            SPECIFIC_USER="$2"
            shift 2
            ;;
        --help)
            head -30 "$0" | tail -25
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to generate a secure random password
generate_password() {
    local length=${1:-24}
    local base=$(head -c 100 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c $((length - 4)))
    echo "${base}Aa1!"
}

# Function to mask password for display
mask_password() {
    local pass="$1"
    echo "${pass:0:4}...${pass: -4}"
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"

    # Check PostgreSQL container
    if ! docker exec pentaho-postgres psql -U postgres -c "SELECT 1" > /dev/null 2>&1; then
        echo -e "${RED}ERROR: PostgreSQL container is not responding${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ PostgreSQL is running${NC}"

    # Check Vault
    VAULT_STATUS=$(curl -s "http://localhost:$VAULT_PORT/v1/sys/health" 2>/dev/null || echo "{}")
    VAULT_SEALED=$(echo "$VAULT_STATUS" | jq -r 'if .sealed == null then "unknown" else .sealed | tostring end' 2>/dev/null)

    if [ "$VAULT_SEALED" = "true" ]; then
        echo -e "${RED}ERROR: Vault is sealed. Run 'docker compose up vault-init' first${NC}"
        exit 1
    elif [ "$VAULT_SEALED" = "unknown" ]; then
        echo -e "${RED}ERROR: Cannot connect to Vault${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Vault is unsealed${NC}"

    # Check for vault-keys.json
    if ! docker exec pentaho-vault test -f /vault/data/vault-keys.json 2>/dev/null; then
        echo -e "${RED}ERROR: Vault keys not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Vault credentials available${NC}"
}

# Function to get Vault root token
get_vault_token() {
    docker exec pentaho-vault cat /vault/data/vault-keys.json 2>/dev/null | jq -r '.root_token'
}

# Function to update PostgreSQL user password
update_postgres_password() {
    local user="$1"
    local new_password="$2"

    echo "  Updating PostgreSQL password for $user..."

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] Would execute: ALTER USER $user WITH PASSWORD '***'"
        return 0
    fi

    docker exec pentaho-postgres psql -U postgres -c \
        "ALTER USER $user WITH PASSWORD '$new_password';" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ PostgreSQL password updated for $user${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed to update PostgreSQL password for $user${NC}"
        return 1
    fi
}

# Function to update Vault secret
update_vault_secret() {
    local token="$1"
    local jcr_pass="$2"
    local pentaho_pass="$3"
    local hibuser_pass="$4"

    echo "Updating secrets in Vault..."

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would update Vault secret at $VAULT_SECRET_PATH"
        return 0
    fi

    # Get existing secrets to preserve other fields
    EXISTING=$(curl -s --header "X-Vault-Token: $token" \
        "http://localhost:$VAULT_PORT/v1/$VAULT_SECRET_PATH" 2>/dev/null)

    POSTGRES_PASS=$(echo "$EXISTING" | jq -r '.data.data.postgres_password // "'"$POSTGRES_PASSWORD"'"')
    JDBC_URL=$(echo "$EXISTING" | jq -r '.data.data.jdbc_url // "jdbc:postgresql://repository:5432/pentaho"')

    # Update secrets with new passwords
    # Note: passwords_source is set to "rotated" to indicate non-default passwords
    RESPONSE=$(curl -s --header "X-Vault-Token: $token" \
        --request POST \
        --data "{
            \"data\": {
                \"postgres_password\": \"$POSTGRES_PASS\",
                \"jcr_user\": \"jcr_user\",
                \"jcr_password\": \"$jcr_pass\",
                \"pentaho_user\": \"pentaho_user\",
                \"pentaho_password\": \"$pentaho_pass\",
                \"hibuser\": \"hibuser\",
                \"hibuser_password\": \"$hibuser_pass\",
                \"jdbc_url\": \"$JDBC_URL\",
                \"passwords_source\": \"rotated\",
                \"rotated_at\": \"$(date -Iseconds)\"
            }
        }" \
        "http://localhost:$VAULT_PORT/v1/$VAULT_SECRET_PATH" 2>/dev/null)

    if echo "$RESPONSE" | jq -e '.data.version' > /dev/null 2>&1; then
        VERSION=$(echo "$RESPONSE" | jq -r '.data.version')
        echo -e "${GREEN}✓ Vault secrets updated (version $VERSION)${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to update Vault secrets${NC}"
        return 1
    fi
}

# Function to update generated-passwords.json
update_passwords_file() {
    local jcr_pass="$1"
    local pentaho_pass="$2"
    local hibuser_pass="$3"

    echo "Updating generated-passwords.json..."

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would update /vault/data/generated-passwords.json"
        return 0
    fi

    docker exec pentaho-vault sh -c "cat > /vault/data/generated-passwords.json << EOF
{
    \"jcr_password\": \"$jcr_pass\",
    \"pentaho_password\": \"$pentaho_pass\",
    \"hibuser_password\": \"$hibuser_pass\",
    \"generated_at\": \"$(date -Iseconds)\",
    \"rotated\": true
}
EOF"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Passwords file updated${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Could not update passwords file${NC}"
        return 0  # Non-fatal
    fi
}

# Function to restart Pentaho
restart_pentaho() {
    if [ "$NO_RESTART" = true ]; then
        echo -e "${YELLOW}Skipping Pentaho restart (--no-restart specified)${NC}"
        echo "You must restart Pentaho manually to apply new credentials:"
        echo "  docker compose restart pentaho-server"
        return 0
    fi

    echo "Restarting Pentaho server to apply new credentials..."

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would restart pentaho-server container"
        return 0
    fi

    cd "$PROJECT_DIR"
    docker compose restart pentaho-server

    echo -e "${GREEN}✓ Pentaho server restarted${NC}"
    echo "Pentaho will fetch new credentials from Vault on startup"
}

# Main execution
main() {
    echo "============================================"
    echo " Pentaho Secret Rotation (PostgreSQL)"
    echo "============================================"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY-RUN MODE - No changes will be made${NC}"
    fi

    echo ""

    # Check prerequisites
    check_prerequisites
    echo ""

    # Get Vault token
    VAULT_TOKEN=$(get_vault_token)
    if [ -z "$VAULT_TOKEN" ]; then
        echo -e "${RED}ERROR: Could not retrieve Vault token${NC}"
        exit 1
    fi

    # Get current passwords from Vault
    echo -e "${BLUE}Current passwords in Vault:${NC}"
    CURRENT_SECRETS=$(curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
        "http://localhost:$VAULT_PORT/v1/$VAULT_SECRET_PATH" 2>/dev/null)

    CURRENT_JCR=$(echo "$CURRENT_SECRETS" | jq -r '.data.data.jcr_password // "N/A"')
    CURRENT_PENTAHO=$(echo "$CURRENT_SECRETS" | jq -r '.data.data.pentaho_password // "N/A"')
    CURRENT_HIBUSER=$(echo "$CURRENT_SECRETS" | jq -r '.data.data.hibuser_password // "N/A"')

    echo "  jcr_user:      $(mask_password "$CURRENT_JCR")"
    echo "  pentaho_user:  $(mask_password "$CURRENT_PENTAHO")"
    echo "  hibuser:       $(mask_password "$CURRENT_HIBUSER")"
    echo ""

    # Generate new passwords
    if [ -n "$SPECIFIC_USER" ]; then
        echo -e "${BLUE}Rotating password for: $SPECIFIC_USER${NC}"
        case "$SPECIFIC_USER" in
            jcr_user)
                NEW_JCR=$(generate_password)
                NEW_PENTAHO="$CURRENT_PENTAHO"
                NEW_HIBUSER="$CURRENT_HIBUSER"
                ;;
            pentaho_user)
                NEW_JCR="$CURRENT_JCR"
                NEW_PENTAHO=$(generate_password)
                NEW_HIBUSER="$CURRENT_HIBUSER"
                ;;
            hibuser)
                NEW_JCR="$CURRENT_JCR"
                NEW_PENTAHO="$CURRENT_PENTAHO"
                NEW_HIBUSER=$(generate_password)
                ;;
            *)
                echo -e "${RED}Unknown user: $SPECIFIC_USER${NC}"
                echo "Valid users: jcr_user, pentaho_user, hibuser"
                exit 1
                ;;
        esac
    else
        echo -e "${BLUE}Generating new passwords for all users...${NC}"
        NEW_JCR=$(generate_password)
        NEW_PENTAHO=$(generate_password)
        NEW_HIBUSER=$(generate_password)
    fi

    echo ""
    echo -e "${BLUE}New passwords:${NC}"
    echo "  jcr_user:      $(mask_password "$NEW_JCR")"
    echo "  pentaho_user:  $(mask_password "$NEW_PENTAHO")"
    echo "  hibuser:       $(mask_password "$NEW_HIBUSER")"
    echo ""

    # Confirmation
    if [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}This will update passwords in PostgreSQL and Vault.${NC}"
        read -p "Continue? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    echo ""
    echo -e "${BLUE}Updating PostgreSQL passwords...${NC}"

    # Update PostgreSQL passwords
    POSTGRES_FAILED=false
    if [ -z "$SPECIFIC_USER" ] || [ "$SPECIFIC_USER" = "jcr_user" ]; then
        update_postgres_password "jcr_user" "$NEW_JCR" || POSTGRES_FAILED=true
    fi
    if [ -z "$SPECIFIC_USER" ] || [ "$SPECIFIC_USER" = "pentaho_user" ]; then
        update_postgres_password "pentaho_user" "$NEW_PENTAHO" || POSTGRES_FAILED=true
    fi
    if [ -z "$SPECIFIC_USER" ] || [ "$SPECIFIC_USER" = "hibuser" ]; then
        update_postgres_password "hibuser" "$NEW_HIBUSER" || POSTGRES_FAILED=true
    fi

    if [ "$POSTGRES_FAILED" = true ]; then
        echo -e "${RED}ERROR: PostgreSQL password update failed. Aborting to prevent inconsistency.${NC}"
        exit 1
    fi

    echo ""

    # Update Vault secrets
    update_vault_secret "$VAULT_TOKEN" "$NEW_JCR" "$NEW_PENTAHO" "$NEW_HIBUSER"
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Vault update failed. PostgreSQL has new passwords but Vault has old ones!${NC}"
        echo "You may need to manually update Vault or revert PostgreSQL passwords."
        exit 1
    fi

    echo ""

    # Update passwords file
    update_passwords_file "$NEW_JCR" "$NEW_PENTAHO" "$NEW_HIBUSER"

    echo ""

    # Restart Pentaho
    restart_pentaho

    echo ""
    echo "============================================"
    echo -e "${GREEN}Secret rotation complete!${NC}"
    echo "============================================"

    if [ "$DRY_RUN" = false ]; then
        echo ""
        echo "Next steps:"
        echo "  1. Verify Pentaho is running: docker compose ps"
        echo "  2. Test login at http://localhost:${PENTAHO_HTTP_PORT:-8090}/pentaho"
        echo "  3. Create a backup: ./scripts/backup-vault.sh"
    fi
}

main
