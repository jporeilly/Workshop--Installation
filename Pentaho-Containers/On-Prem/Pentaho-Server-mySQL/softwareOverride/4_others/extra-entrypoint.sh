#!/bin/bash
# =============================================================================
# Pentaho Vault Integration - Extra Entrypoint Script
# =============================================================================
# Deployment: Pentaho Server with MySQL
#
# PURPOSE:
#   This script runs during Pentaho container startup to fetch database
#   credentials from HashiCorp Vault and inject them into context.xml.
#   This enables dynamic secret management without hardcoding passwords.
#
# HOW IT WORKS:
#   1. Waits for Vault to be ready and unsealed
#   2. Authenticates with Vault using AppRole credentials
#   3. Fetches database passwords from Vault
#   4. Updates context.xml with the retrieved credentials
#   5. Pentaho starts with the injected credentials
#
# WHEN THIS RUNS:
#   This script is executed by the Pentaho container's docker-entrypoint.sh
#   during startup. It runs BEFORE Tomcat/Pentaho starts, ensuring credentials
#   are in place before any database connections are attempted.
#
# REQUIREMENTS:
#   - Vault must be unsealed and accessible at VAULT_ADDR
#   - AppRole credentials must exist at /vault/data/approle-creds.json
#   - The vault_data volume must be mounted read-only at /vault/data
#
# GRACEFUL FALLBACK:
#   If Vault is unavailable or authentication fails, this script exits with
#   code 0 (success) and Pentaho will use the default credentials from
#   context.xml. This prevents container restart loops.
#
# ENVIRONMENT VARIABLES:
#   VAULT_ADDR          - Vault server address (default: http://pentaho-vault:8200)
#   VAULT_SECRET_PATH   - Path to secrets in Vault (default: secret/data/pentaho/mysql)
#   VAULT_ENABLED       - Set to "false" to skip Vault integration
#   VAULT_MAX_RETRIES   - Max attempts to reach Vault (default: 30)
#   VAULT_RETRY_INTERVAL - Seconds between retries (default: 2)
#
# TECHNICAL NOTES:
#   - Uses grep/sed for JSON parsing because jq is not installed in the
#     Pentaho container image
#   - Stderr is used for status messages so stdout can return clean values
#   - File permissions on approle-creds.json must be 644 (not 600) because
#     the Pentaho container runs as UID 5000, not as the vault user
#
# =============================================================================

# Don't use set -e since we handle errors gracefully
# If any step fails, we fall back to default credentials rather than crashing
# set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# Vault server address - uses Docker network hostname
VAULT_ADDR="${VAULT_ADDR:-http://pentaho-vault:8200}"

# Path to secrets in Vault's KV v2 engine
# Note: The actual API path is /v1/secret/data/... for KV v2
VAULT_SECRET_PATH="${VAULT_SECRET_PATH:-secret/data/pentaho/mysql}"

# File containing AppRole credentials (created by vault-init.sh)
APPROLE_CREDS_FILE="/vault/data/approle-creds.json"

# Pentaho's context.xml with JNDI DataSource definitions
CONTEXT_XML="$PENTAHO_SERVER_PATH/tomcat/webapps/pentaho/META-INF/context.xml"

# Retry configuration for waiting on Vault
MAX_RETRIES="${VAULT_MAX_RETRIES:-30}"
RETRY_INTERVAL="${VAULT_RETRY_INTERVAL:-2}"

# ANSI color codes for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# -----------------------------------------------------------------------------
# JSON Parsing Functions
# -----------------------------------------------------------------------------
# These functions extract values from JSON without jq, using only grep and sed
# which are available in the Pentaho container.

# Extract a string value from JSON
# Usage: json_get '{"key": "value"}' "key"
# Returns: value (without quotes)
json_get() {
    local json="$1"
    local key="$2"
    # Pattern: "key" : "value" (with flexible whitespace)
    # -o: Only output the matching part
    # -E: Use extended regex
    echo "$json" | grep -oE "\"$key\" *: *\"[^\"]+\"" | sed -E "s/\"$key\" *: *\"([^\"]+)\"/\1/"
}

# Extract a boolean value from JSON
# Usage: json_get_bool '{"sealed": false}' "sealed"
# Returns: true or false (as string)
json_get_bool() {
    local json="$1"
    local key="$2"
    echo "$json" | grep -oE "\"$key\" *: *(true|false)" | sed -E "s/\"$key\" *: *//"
}

# -----------------------------------------------------------------------------
# Main Script Start
# -----------------------------------------------------------------------------

echo "============================================"
echo " Pentaho Vault Integration"
echo "============================================"

# -----------------------------------------------------------------------------
# Check if Vault integration is enabled
# -----------------------------------------------------------------------------
# Setting VAULT_ENABLED=false in docker-compose.yml allows disabling
# Vault integration for development or testing without Vault
if [ "${VAULT_ENABLED:-true}" = "false" ]; then
    echo -e "${YELLOW}Vault integration disabled (VAULT_ENABLED=false)${NC}"
    echo "Using default credentials from context.xml"
    exit 0
fi

# -----------------------------------------------------------------------------
# Check for AppRole credentials file
# -----------------------------------------------------------------------------
# This file is created by vault-init.sh and shared via the vault_data volume
# If it doesn't exist, Vault hasn't been initialized yet
if [ ! -f "$APPROLE_CREDS_FILE" ]; then
    echo -e "${YELLOW}AppRole credentials not found at $APPROLE_CREDS_FILE${NC}"
    echo "Vault integration skipped - using default credentials"
    exit 0
fi

# -----------------------------------------------------------------------------
# Function: Wait for Vault to be unsealed
# -----------------------------------------------------------------------------
# Vault must be initialized AND unsealed to serve secrets.
# This function polls Vault's health endpoint until it reports ready.
# Returns 0 on success, 1 if Vault doesn't become ready within MAX_RETRIES
wait_for_vault() {
    local retries=0
    echo "Waiting for Vault to be ready and unsealed..."

    while [ $retries -lt $MAX_RETRIES ]; do
        # Query Vault's health endpoint
        HEALTH=$(curl -s "${VAULT_ADDR}/v1/sys/health" 2>/dev/null || echo "")

        if [ -n "$HEALTH" ]; then
            # Parse the JSON response
            SEALED=$(json_get_bool "$HEALTH" "sealed")
            INIT=$(json_get_bool "$HEALTH" "initialized")

            # Vault is ready when initialized=true AND sealed=false
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

# -----------------------------------------------------------------------------
# Function: Authenticate with Vault using AppRole
# -----------------------------------------------------------------------------
# AppRole is a machine-oriented auth method. We use:
#   - role_id: A static identifier (like a username)
#   - secret_id: A dynamic credential (like a password)
# Together these produce a short-lived Vault token for reading secrets.
#
# IMPORTANT: All status messages go to stderr (>&2) so that only the
# token is returned via stdout. This allows: TOKEN=$(authenticate_vault)
authenticate_vault() {
    # Read AppRole credentials from the shared file
    CREDS=$(cat "$APPROLE_CREDS_FILE" 2>/dev/null || echo "")
    ROLE_ID=$(json_get "$CREDS" "role_id")
    SECRET_ID=$(json_get "$CREDS" "secret_id")

    # Validate credentials were parsed successfully
    if [ -z "$ROLE_ID" ] || [ -z "$SECRET_ID" ]; then
        echo -e "${RED}Invalid AppRole credentials${NC}" >&2
        return 1
    fi

    echo "Authenticating with Vault using AppRole..." >&2

    # POST to the AppRole login endpoint
    AUTH_RESPONSE=$(curl -s --request POST \
        --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
        "${VAULT_ADDR}/v1/auth/approle/login" 2>/dev/null)

    # Extract the client token from the response
    CLIENT_TOKEN=$(json_get "$AUTH_RESPONSE" "client_token")

    if [ -z "$CLIENT_TOKEN" ]; then
        echo -e "${RED}Failed to authenticate with Vault${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}Successfully authenticated with Vault${NC}" >&2

    # Return ONLY the token to stdout (not status messages)
    echo "$CLIENT_TOKEN"
}

# -----------------------------------------------------------------------------
# Function: Fetch secrets from Vault
# -----------------------------------------------------------------------------
# Retrieves database credentials from Vault's KV v2 secrets engine.
# The secrets are stored at: secret/data/pentaho/mysql
#
# Response structure (KV v2):
#   {
#     "data": {
#       "data": {
#         "jcr_user": "jcr_user",
#         "jcr_password": "...",
#         ...
#       },
#       "metadata": {...}
#     }
#   }
#
# Note: The double "data" nesting is specific to KV v2.
# Our json_get function handles this by just looking for the key anywhere.
fetch_secrets() {
    local token="$1"

    echo "Fetching database credentials from Vault..."

    # GET the secrets using the Vault token
    SECRETS=$(curl -s --header "X-Vault-Token: $token" \
        "${VAULT_ADDR}/v1/${VAULT_SECRET_PATH}" 2>/dev/null)

    # Extract each credential from the response
    # These variable names are used in update_context_xml()
    JCR_USER=$(json_get "$SECRETS" "jcr_user")
    JCR_PASSWORD=$(json_get "$SECRETS" "jcr_password")
    PENTAHO_USER=$(json_get "$SECRETS" "pentaho_user")
    PENTAHO_PASSWORD=$(json_get "$SECRETS" "pentaho_password")
    HIBUSER=$(json_get "$SECRETS" "hibuser")
    HIBUSER_PASSWORD=$(json_get "$SECRETS" "hibuser_password")

    # Validate that we got all required passwords
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

# -----------------------------------------------------------------------------
# Function: Update context.xml with credentials
# -----------------------------------------------------------------------------
# Pentaho uses Tomcat's context.xml to define JNDI DataSources.
# Each DataSource has: username="xxx" password="yyy"
#
# This function uses sed to replace passwords in-place:
#   username="hibuser" password="oldpass" → username="hibuser" password="newpass"
#
# The credentials map to these Pentaho components:
#   - hibuser: Hibernate, Audit, PDI Operations Mart
#   - pentaho_user: Quartz scheduler
#   - jcr_user: JackRabbit content repository
update_context_xml() {
    if [ ! -f "$CONTEXT_XML" ]; then
        echo -e "${RED}context.xml not found at $CONTEXT_XML${NC}"
        return 1
    fi

    echo "Updating context.xml with Vault credentials..."

    # Create backup before modification
    cp "$CONTEXT_XML" "${CONTEXT_XML}.bak"

    # Replace each user's password using sed
    # Pattern: username="USER" password="anything" → username="USER" password="NEWPASS"
    # The /g flag replaces all occurrences (some users appear multiple times)

    # hibuser - used by: Hibernate, Audit, PDI_Operations_Mart, pentaho_operations_mart, live_logging_info
    sed -i "s/username=\"hibuser\" password=\"[^\"]*\"/username=\"hibuser\" password=\"$HIBUSER_PASSWORD\"/g" "$CONTEXT_XML"

    # pentaho_user - used by: Quartz scheduler
    sed -i "s/username=\"pentaho_user\" password=\"[^\"]*\"/username=\"pentaho_user\" password=\"$PENTAHO_PASSWORD\"/g" "$CONTEXT_XML"

    # jcr_user - used by: JackRabbit content repository
    sed -i "s/username=\"jcr_user\" password=\"[^\"]*\"/username=\"jcr_user\" password=\"$JCR_PASSWORD\"/g" "$CONTEXT_XML"

    echo -e "${GREEN}Successfully updated context.xml with Vault credentials${NC}"

    # Verify the updates were applied correctly
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

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
main() {
    # Step 1: Wait for Vault to be ready
    if ! wait_for_vault; then
        echo -e "${YELLOW}Continuing with default credentials (Vault unavailable)${NC}"
        exit 0  # Exit successfully to prevent container restart
    fi

    # Step 2: Authenticate with Vault
    CLIENT_TOKEN=$(authenticate_vault)
    if [ -z "$CLIENT_TOKEN" ]; then
        echo -e "${YELLOW}Continuing with default credentials (auth failed)${NC}"
        exit 0  # Exit successfully to prevent container restart
    fi

    # Step 3: Fetch secrets from Vault
    if ! fetch_secrets "$CLIENT_TOKEN"; then
        echo -e "${YELLOW}Continuing with default credentials (fetch failed)${NC}"
        exit 0  # Exit successfully to prevent container restart
    fi

    # Step 4: Update context.xml with credentials
    if ! update_context_xml; then
        echo -e "${RED}Failed to update context.xml${NC}"
        # Restore backup if something went wrong
        if [ -f "${CONTEXT_XML}.bak" ]; then
            mv "${CONTEXT_XML}.bak" "$CONTEXT_XML"
        fi
        exit 1  # This is a real error - context.xml is corrupted
    fi

    # Clean up backup file
    rm -f "${CONTEXT_XML}.bak"

    echo "============================================"
    echo -e "${GREEN}Vault integration complete!${NC}"
    echo "Pentaho will use credentials from Vault"
    echo "============================================"
}

# Run main function
main
