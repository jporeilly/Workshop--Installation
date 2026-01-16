#!/bin/bash
# =============================================================================
# Pentaho Vault Integration - Extra Entrypoint Script
# =============================================================================
# Deployment: Pentaho Server with PostgreSQL
#
# PURPOSE:
#   This script runs during Pentaho container startup (called by docker-entrypoint.sh).
#   It fetches database credentials from HashiCorp Vault and injects them into
#   Tomcat's context.xml configuration file.
#
# HOW IT'S CALLED:
#   The docker-entrypoint.sh script in the Pentaho container calls this script
#   if it exists in the /docker-entrypoint-init/4_others directory. This happens
#   BEFORE Tomcat starts, ensuring credentials are in place.
#
# STARTUP FLOW:
#   ┌──────────────────────────────────────────────────────────────────┐
#   │  1. Container starts → docker-entrypoint.sh runs                  │
#   │                    ↓                                              │
#   │  2. extra-entrypoint.sh is called                                 │
#   │                    ↓                                              │
#   │  3. Wait for Vault to be ready and unsealed                       │
#   │                    ↓                                              │
#   │  4. Authenticate with Vault using AppRole (role_id + secret_id)   │
#   │                    ↓                                              │
#   │  5. Fetch credentials from secret/data/pentaho/postgresql         │
#   │                    ↓                                              │
#   │  6. Update context.xml with fetched passwords                     │
#   │                    ↓                                              │
#   │  7. Tomcat starts with correct database credentials               │
#   └──────────────────────────────────────────────────────────────────┘
#
# REQUIREMENTS:
#   - Vault must be initialized and unsealed
#   - AppRole credentials must exist at /vault/data/approle-creds.json
#   - context.xml must be at $PENTAHO_SERVER_PATH/tomcat/webapps/pentaho/META-INF/
#
# GRACEFUL FALLBACK:
#   If Vault is unavailable, authentication fails, or secrets can't be fetched,
#   this script exits with code 0 (success) and Pentaho starts with whatever
#   credentials are already in context.xml. This prevents startup failures
#   when Vault is temporarily unavailable.
#
# TECHNICAL NOTES:
#   - Uses grep/sed for JSON parsing instead of jq (not installed in container)
#   - Creates backup of context.xml before modification (restored on failure)
#   - All status messages go to stderr, only return values to stdout
#   - Maximum retry time: MAX_RETRIES * RETRY_INTERVAL seconds (default: 60s)
#
# ENVIRONMENT VARIABLES:
#   VAULT_ADDR          - Vault server address (default: http://pentaho-vault:8200)
#   VAULT_SECRET_PATH   - Path to secrets (default: secret/data/pentaho/postgresql)
#   VAULT_ENABLED       - Set to "false" to skip Vault integration
#   VAULT_MAX_RETRIES   - Number of retries waiting for Vault (default: 30)
#   VAULT_RETRY_INTERVAL - Seconds between retries (default: 2)
#
# =============================================================================

# Don't use set -e since we handle errors gracefully and want to fall back
# to default credentials rather than failing the container startup
# set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
VAULT_ADDR="${VAULT_ADDR:-http://pentaho-vault:8200}"
VAULT_SECRET_PATH="${VAULT_SECRET_PATH:-secret/data/pentaho/postgresql}"
APPROLE_CREDS_FILE="/vault/data/approle-creds.json"
CONTEXT_XML="$PENTAHO_SERVER_PATH/tomcat/webapps/pentaho/META-INF/context.xml"
MAX_RETRIES="${VAULT_MAX_RETRIES:-30}"
RETRY_INTERVAL="${VAULT_RETRY_INTERVAL:-2}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Simple JSON value extractor (no jq required)
# Usage: json_get '{"key": "value"}' "key"
json_get() {
    local json="$1"
    local key="$2"
    # Use extended regex for better compatibility
    echo "$json" | grep -oE "\"$key\" *: *\"[^\"]+\"" | sed -E "s/\"$key\" *: *\"([^\"]+)\"/\1/"
}

# Extract boolean value from JSON
json_get_bool() {
    local json="$1"
    local key="$2"
    # Use extended regex for better compatibility
    echo "$json" | grep -oE "\"$key\" *: *(true|false)" | sed -E "s/\"$key\" *: *//"
}

echo "============================================"
echo " Pentaho Vault Integration"
echo "============================================"

# Check if Vault integration is enabled
if [ "${VAULT_ENABLED:-true}" = "false" ]; then
    echo -e "${YELLOW}Vault integration disabled (VAULT_ENABLED=false)${NC}"
    echo "Using default credentials from context.xml"
    exit 0
fi

# Check if AppRole credentials exist
if [ ! -f "$APPROLE_CREDS_FILE" ]; then
    echo -e "${YELLOW}AppRole credentials not found at $APPROLE_CREDS_FILE${NC}"
    echo "Vault integration skipped - using default credentials"
    exit 0
fi

# Function to wait for Vault to be unsealed
wait_for_vault() {
    local retries=0
    echo "Waiting for Vault to be ready and unsealed..."

    while [ $retries -lt $MAX_RETRIES ]; do
        HEALTH=$(curl -s "${VAULT_ADDR}/v1/sys/health" 2>/dev/null || echo "")

        if [ -n "$HEALTH" ]; then
            SEALED=$(json_get_bool "$HEALTH" "sealed")
            INIT=$(json_get_bool "$HEALTH" "initialized")

            if [ "$SEALED" = "false" ] && [ "$INIT" = "true" ]; then
                echo -e "${GREEN}Vault is ready and unsealed${NC}"
                return 0
            fi

            retries=$((retries + 1))
            echo "  Attempt $retries/$MAX_RETRIES - Vault sealed=$SEALED, init=$INIT"
        else
            retries=$((retries + 1))
            echo "  Attempt $retries/$MAX_RETRIES - Vault not responding"
        fi

        sleep $RETRY_INTERVAL
    done

    echo -e "${RED}Vault not available after $MAX_RETRIES attempts${NC}"
    return 1
}

# Function to authenticate with Vault using AppRole
authenticate_vault() {
    # Read AppRole credentials from file
    CREDS=$(cat "$APPROLE_CREDS_FILE" 2>/dev/null || echo "")
    ROLE_ID=$(json_get "$CREDS" "role_id")
    SECRET_ID=$(json_get "$CREDS" "secret_id")

    if [ -z "$ROLE_ID" ] || [ -z "$SECRET_ID" ]; then
        echo -e "${RED}Invalid AppRole credentials${NC}" >&2
        return 1
    fi

    echo "Authenticating with Vault using AppRole..." >&2
    AUTH_RESPONSE=$(curl -s --request POST \
        --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
        "${VAULT_ADDR}/v1/auth/approle/login" 2>/dev/null)

    CLIENT_TOKEN=$(json_get "$AUTH_RESPONSE" "client_token")

    if [ -z "$CLIENT_TOKEN" ]; then
        echo -e "${RED}Failed to authenticate with Vault${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}Successfully authenticated with Vault${NC}" >&2
    # Return ONLY the token to stdout
    echo "$CLIENT_TOKEN"
}

# Function to fetch secrets from Vault
fetch_secrets() {
    local token="$1"

    echo "Fetching database credentials from Vault..."
    SECRETS=$(curl -s --header "X-Vault-Token: $token" \
        "${VAULT_ADDR}/v1/${VAULT_SECRET_PATH}" 2>/dev/null)

    # Extract credentials from nested data.data structure
    # The response is like: {"data":{"data":{"jcr_user":"...","jcr_password":"..."}}}
    JCR_USER=$(json_get "$SECRETS" "jcr_user")
    JCR_PASSWORD=$(json_get "$SECRETS" "jcr_password")
    PENTAHO_USER=$(json_get "$SECRETS" "pentaho_user")
    PENTAHO_PASSWORD=$(json_get "$SECRETS" "pentaho_password")
    HIBUSER=$(json_get "$SECRETS" "hibuser")
    HIBUSER_PASSWORD=$(json_get "$SECRETS" "hibuser_password")

    if [ -z "$JCR_PASSWORD" ] || [ -z "$PENTAHO_PASSWORD" ] || [ -z "$HIBUSER_PASSWORD" ]; then
        echo -e "${RED}Failed to fetch complete credentials from Vault${NC}"
        echo "  JCR_PASSWORD: $([ -n "$JCR_PASSWORD" ] && echo "OK" || echo "MISSING")"
        echo "  PENTAHO_PASSWORD: $([ -n "$PENTAHO_PASSWORD" ] && echo "OK" || echo "MISSING")"
        echo "  HIBUSER_PASSWORD: $([ -n "$HIBUSER_PASSWORD" ] && echo "OK" || echo "MISSING")"
        return 1
    fi

    echo -e "${GREEN}Successfully fetched credentials from Vault${NC}"
    return 0
}

# Function to update context.xml with credentials
update_context_xml() {
    if [ ! -f "$CONTEXT_XML" ]; then
        echo -e "${RED}context.xml not found at $CONTEXT_XML${NC}"
        return 1
    fi

    echo "Updating context.xml with Vault credentials..."

    # Create backup
    cp "$CONTEXT_XML" "${CONTEXT_XML}.bak"

    # Use sed to replace credentials
    # Replace hibuser password (used by Hibernate, Audit, PDI_Operations_Mart, pentaho_operations_mart, live_logging_info)
    sed -i "s/username=\"hibuser\" password=\"[^\"]*\"/username=\"hibuser\" password=\"$HIBUSER_PASSWORD\"/g" "$CONTEXT_XML"

    # Replace pentaho_user password (used by Quartz)
    sed -i "s/username=\"pentaho_user\" password=\"[^\"]*\"/username=\"pentaho_user\" password=\"$PENTAHO_PASSWORD\"/g" "$CONTEXT_XML"

    # Replace jcr_user password (used by JackRabbit)
    sed -i "s/username=\"jcr_user\" password=\"[^\"]*\"/username=\"jcr_user\" password=\"$JCR_PASSWORD\"/g" "$CONTEXT_XML"

    echo -e "${GREEN}Successfully updated context.xml with Vault credentials${NC}"

    # Verify the update (without showing actual passwords)
    echo "Verifying credential injection:"
    if grep -q "username=\"hibuser\" password=\"$HIBUSER_PASSWORD\"" "$CONTEXT_XML"; then
        echo "  - hibuser: OK"
    else
        echo "  - hibuser: FAILED"
    fi
    if grep -q "username=\"pentaho_user\" password=\"$PENTAHO_PASSWORD\"" "$CONTEXT_XML"; then
        echo "  - pentaho_user: OK"
    else
        echo "  - pentaho_user: FAILED"
    fi
    if grep -q "username=\"jcr_user\" password=\"$JCR_PASSWORD\"" "$CONTEXT_XML"; then
        echo "  - jcr_user: OK"
    else
        echo "  - jcr_user: FAILED"
    fi

    return 0
}

# Main execution
main() {
    # Wait for Vault
    if ! wait_for_vault; then
        echo -e "${YELLOW}Continuing with default credentials (Vault unavailable)${NC}"
        exit 0
    fi

    # Authenticate
    CLIENT_TOKEN=$(authenticate_vault)
    if [ -z "$CLIENT_TOKEN" ]; then
        echo -e "${YELLOW}Continuing with default credentials (auth failed)${NC}"
        exit 0
    fi

    # Fetch secrets
    if ! fetch_secrets "$CLIENT_TOKEN"; then
        echo -e "${YELLOW}Continuing with default credentials (fetch failed)${NC}"
        exit 0
    fi

    # Update context.xml
    if ! update_context_xml; then
        echo -e "${RED}Failed to update context.xml${NC}"
        # Restore backup if it exists
        if [ -f "${CONTEXT_XML}.bak" ]; then
            mv "${CONTEXT_XML}.bak" "$CONTEXT_XML"
        fi
        exit 1
    fi

    # Clean up backup
    rm -f "${CONTEXT_XML}.bak"

    echo "============================================"
    echo -e "${GREEN}Vault integration complete!${NC}"
    echo "Pentaho will use credentials from Vault"
    echo "============================================"
}

main
