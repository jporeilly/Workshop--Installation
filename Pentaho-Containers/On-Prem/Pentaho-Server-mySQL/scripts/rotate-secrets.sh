#!/bin/bash
# =============================================================================
# Pentaho Secret Rotation Script
# =============================================================================
# Deployment: Pentaho Server with MySQL
#
# PURPOSE:
#   This script rotates database passwords for Pentaho service accounts.
#   It updates both MySQL and Vault, then restarts Pentaho to pick up
#   the new credentials.
#
# WHEN TO USE:
#   1. After initial deployment - Default passwords ("password") are insecure
#   2. Periodic rotation - Best practice is every 30-90 days
#   3. After suspected compromise - Immediate rotation
#   4. Before/after team member changes - Security hygiene
#
# WHAT IT DOES:
#   1. Generates new secure random passwords
#   2. Updates user passwords in MySQL
#   3. Stores new passwords in Vault
#   4. Saves passwords to generated-passwords.json (for vault-init.sh)
#   5. Restarts Pentaho to fetch new credentials from Vault
#
# ROTATION FLOW:
#   rotate-secrets.sh
#        │
#        ├─► MySQL: ALTER USER ... IDENTIFIED BY 'new_pass'
#        │
#        ├─► Vault: PUT secret/data/pentaho/mysql
#        │
#        ├─► File: /vault/data/generated-passwords.json
#        │
#        └─► Docker: restart pentaho-server
#                      │
#                      └─► extra-entrypoint.sh fetches new creds from Vault
#
# USAGE:
#   ./scripts/rotate-secrets.sh [options]
#
# OPTIONS:
#   --dry-run     Show what would happen without making changes
#   --no-restart  Update passwords but don't restart Pentaho
#   --user USER   Only rotate specific user (jcr_user, pentaho_user, hibuser)
#   --help        Show this help message
#
# EXAMPLES:
#   ./scripts/rotate-secrets.sh                    # Rotate all passwords
#   ./scripts/rotate-secrets.sh --dry-run          # Preview changes
#   ./scripts/rotate-secrets.sh --user hibuser     # Rotate only hibuser
#   ./scripts/rotate-secrets.sh --no-restart       # Don't restart Pentaho
#
# REQUIREMENTS:
#   - MySQL container must be running
#   - Vault must be initialized and unsealed
#   - Script must be run from the project directory
#   - jq must be installed on the host
#
# PASSWORD POLICY:
#   Generated passwords are 24 characters:
#   - 20 random alphanumeric characters
#   - Suffix "Aa1!" to ensure complexity requirements
#   - Total: uppercase, lowercase, numbers, special chars
#
# RECOVERY:
#   If rotation fails partway through:
#   1. Check what succeeded in the output
#   2. If MySQL updated but Vault didn't: manually update Vault
#   3. If Vault updated but Pentaho won't start: check generated-passwords.json
#   4. Worst case: redeploy with fresh database
#
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# ANSI color codes for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Determine script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables from .env if it exists
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Database configuration
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-password}"

# Vault configuration
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_PORT="${VAULT_PORT:-8200}"
VAULT_SECRET_PATH="secret/data/pentaho/mysql"

# Command-line options (defaults)
DRY_RUN=false
NO_RESTART=false
SPECIFIC_USER=""

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            # Preview mode - no changes made
            DRY_RUN=true
            shift
            ;;
        --no-restart)
            # Update passwords but leave Pentaho running with old creds
            # Useful if you want to rotate during a maintenance window
            NO_RESTART=true
            shift
            ;;
        --user)
            # Rotate only one specific user's password
            SPECIFIC_USER="$2"
            shift 2
            ;;
        --help)
            # Show usage from script header
            head -60 "$0" | tail -50
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Generate a secure random password
# Format: 20 random alphanumeric + "Aa1!" suffix
# This ensures the password meets common complexity requirements:
#   - At least one uppercase (A)
#   - At least one lowercase (a)
#   - At least one number (1)
#   - At least one special character (!)
generate_password() {
    local length=${1:-24}
    local base=$(head -c 100 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c $((length - 4)))
    echo "${base}Aa1!"
}

# Mask password for display (show first 4 and last 4 chars)
# Example: "MySecurePassword123!" → "MySe...123!"
mask_password() {
    local pass="$1"
    echo "${pass:0:4}...${pass: -4}"
}

# -----------------------------------------------------------------------------
# Prerequisite Checks
# -----------------------------------------------------------------------------
# Verify all required services are available before attempting rotation

check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"

    # Check MySQL container is running and accessible
    if ! docker exec pentaho-mysql mysqladmin ping -uroot -p"$MYSQL_ROOT_PASSWORD" > /dev/null 2>&1; then
        echo -e "${RED}ERROR: MySQL container is not responding${NC}"
        echo "  Verify: docker compose ps pentaho-mysql"
        exit 1
    fi
    echo -e "${GREEN}✓ MySQL is running${NC}"

    # Check Vault is running and unsealed
    VAULT_STATUS=$(curl -s "http://localhost:$VAULT_PORT/v1/sys/health" 2>/dev/null || echo "{}")
    VAULT_SEALED=$(echo "$VAULT_STATUS" | jq -r 'if .sealed == null then "unknown" else .sealed | tostring end' 2>/dev/null)

    if [ "$VAULT_SEALED" = "true" ]; then
        echo -e "${RED}ERROR: Vault is sealed${NC}"
        echo "  Run: docker compose up vault-init"
        exit 1
    elif [ "$VAULT_SEALED" = "unknown" ]; then
        echo -e "${RED}ERROR: Cannot connect to Vault${NC}"
        echo "  Verify: docker compose ps pentaho-vault"
        exit 1
    fi
    echo -e "${GREEN}✓ Vault is unsealed${NC}"

    # Check vault-keys.json exists (contains root token)
    if ! docker exec pentaho-vault test -f /vault/data/vault-keys.json 2>/dev/null; then
        echo -e "${RED}ERROR: Vault keys not found${NC}"
        echo "  Vault may not be initialized. Run: docker compose up vault-init"
        exit 1
    fi
    echo -e "${GREEN}✓ Vault credentials available${NC}"
}

# Get Vault root token from the keys file
get_vault_token() {
    docker exec pentaho-vault cat /vault/data/vault-keys.json 2>/dev/null | jq -r '.root_token'
}

# -----------------------------------------------------------------------------
# MySQL Password Update
# -----------------------------------------------------------------------------
# Updates a user's password in MySQL using ALTER USER

update_mysql_password() {
    local user="$1"
    local new_password="$2"

    echo "  Updating MySQL password for $user..."

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY-RUN] Would execute: ALTER USER '$user'@'%' IDENTIFIED BY '***'"
        return 0
    fi

    # Execute the password change
    # The @'%' allows connections from any host (required for Docker networking)
    docker exec pentaho-mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e \
        "ALTER USER '$user'@'%' IDENTIFIED BY '$new_password'; FLUSH PRIVILEGES;" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓ MySQL password updated for $user${NC}"
        return 0
    else
        echo -e "  ${RED}✗ Failed to update MySQL password for $user${NC}"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Vault Secret Update
# -----------------------------------------------------------------------------
# Stores all passwords in Vault, preserving other fields like jdbc_url

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

    # Get existing secrets to preserve non-password fields
    EXISTING=$(curl -s --header "X-Vault-Token: $token" \
        "http://localhost:$VAULT_PORT/v1/$VAULT_SECRET_PATH" 2>/dev/null)

    ROOT_PASS=$(echo "$EXISTING" | jq -r '.data.data.root_password // "password"')
    JDBC_URL=$(echo "$EXISTING" | jq -r '.data.data.jdbc_url // "jdbc:mysql://repository:3306/pentaho"')

    # Write updated secrets to Vault
    # KV v2 requires the data to be wrapped in a "data" object
    RESPONSE=$(curl -s --header "X-Vault-Token: $token" \
        --request POST \
        --data "{
            \"data\": {
                \"root_password\": \"$ROOT_PASS\",
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

    # Verify the update succeeded by checking for version number
    if echo "$RESPONSE" | jq -e '.data.version' > /dev/null 2>&1; then
        VERSION=$(echo "$RESPONSE" | jq -r '.data.version')
        echo -e "${GREEN}✓ Vault secrets updated (version $VERSION)${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to update Vault secrets${NC}"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Password File Update
# -----------------------------------------------------------------------------
# Saves passwords to generated-passwords.json so vault-init.sh uses them
# on subsequent container restarts

update_passwords_file() {
    local jcr_pass="$1"
    local pentaho_pass="$2"
    local hibuser_pass="$3"

    echo "Updating generated-passwords.json..."

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would update /vault/data/generated-passwords.json"
        return 0
    fi

    # Write the passwords file inside the Vault container
    # This file is read by vault-init.sh on restarts
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
        return 0  # Non-fatal - Vault is the source of truth
    fi
}

# -----------------------------------------------------------------------------
# Pentaho Restart
# -----------------------------------------------------------------------------
# Restarts Pentaho container so extra-entrypoint.sh fetches new credentials

restart_pentaho() {
    if [ "$NO_RESTART" = true ]; then
        echo -e "${YELLOW}Skipping Pentaho restart (--no-restart specified)${NC}"
        echo ""
        echo "To apply new credentials, restart Pentaho manually:"
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

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

main() {
    echo "============================================"
    echo " Pentaho Secret Rotation"
    echo "============================================"

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}DRY-RUN MODE - No changes will be made${NC}"
    fi

    echo ""

    # Step 1: Verify prerequisites
    check_prerequisites
    echo ""

    # Step 2: Get Vault root token
    VAULT_TOKEN=$(get_vault_token)
    if [ -z "$VAULT_TOKEN" ]; then
        echo -e "${RED}ERROR: Could not retrieve Vault token${NC}"
        exit 1
    fi

    # Step 3: Display current passwords from Vault
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

    # Step 4: Generate new passwords
    if [ -n "$SPECIFIC_USER" ]; then
        # Rotate only the specified user
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
        # Rotate all users
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

    # Step 5: Confirm before proceeding (unless dry-run)
    if [ "$DRY_RUN" = false ]; then
        echo -e "${YELLOW}This will update passwords in MySQL and Vault.${NC}"
        read -p "Continue? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    echo ""
    echo -e "${BLUE}Updating MySQL passwords...${NC}"

    # Step 6: Update MySQL passwords
    # This is done FIRST because it's the most likely to fail
    # If MySQL fails, Vault stays in sync with the old passwords
    MYSQL_FAILED=false
    if [ -z "$SPECIFIC_USER" ] || [ "$SPECIFIC_USER" = "jcr_user" ]; then
        update_mysql_password "jcr_user" "$NEW_JCR" || MYSQL_FAILED=true
    fi
    if [ -z "$SPECIFIC_USER" ] || [ "$SPECIFIC_USER" = "pentaho_user" ]; then
        update_mysql_password "pentaho_user" "$NEW_PENTAHO" || MYSQL_FAILED=true
    fi
    if [ -z "$SPECIFIC_USER" ] || [ "$SPECIFIC_USER" = "hibuser" ]; then
        update_mysql_password "hibuser" "$NEW_HIBUSER" || MYSQL_FAILED=true
    fi

    if [ "$MYSQL_FAILED" = true ]; then
        echo -e "${RED}ERROR: MySQL password update failed. Aborting.${NC}"
        echo "Vault was NOT updated - passwords remain in sync."
        exit 1
    fi

    echo ""

    # Step 7: Update Vault secrets
    update_vault_secret "$VAULT_TOKEN" "$NEW_JCR" "$NEW_PENTAHO" "$NEW_HIBUSER"
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Vault update failed!${NC}"
        echo ""
        echo "CRITICAL: MySQL has new passwords but Vault has old ones!"
        echo "Manual intervention required:"
        echo "  1. Update Vault manually with the new passwords, OR"
        echo "  2. Revert MySQL passwords to match Vault"
        exit 1
    fi

    echo ""

    # Step 8: Update the passwords file for vault-init.sh
    update_passwords_file "$NEW_JCR" "$NEW_PENTAHO" "$NEW_HIBUSER"

    echo ""

    # Step 9: Restart Pentaho to pick up new credentials
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
        echo "  3. Recommended: Schedule next rotation in 30-90 days"
        echo ""
        echo "Rotation history is tracked in Vault (version numbers)"
        echo "Last rotation: $(date -Iseconds)"
    fi
}

# Run the main function
main
