#!/bin/bash
# =============================================================================
# Vault Initialization and Secrets Setup Script
# =============================================================================
# Deployment: Pentaho Server with Oracle Database
#
# PURPOSE:
#   This script initializes HashiCorp Vault for secure secrets management and
#   stores the initial database credentials. It runs automatically during
#   container startup via docker-compose.
#
# WHAT THIS SCRIPT DOES:
#   1. Waits for Vault to be ready
#   2. Initializes Vault (first run only) - creates unseal keys and root token
#   3. Unseals Vault using stored keys
#   4. Enables KV secrets engine v2
#   5. Stores database credentials in Vault (matches Oracle init scripts)
#   6. Configures AppRole authentication for Pentaho server
#   7. Saves AppRole credentials for Pentaho to use
#
# DEPLOYMENT FLOW:
#   On a CLEAN deployment, this is the order of operations:
#
#   1. docker compose up -d
#   2. Oracle container starts → runs db_init_oracle/*.sql scripts
#      → Creates users with default password "password"
#   3. Vault container starts → runs this script
#      → Stores the SAME default passwords in Vault
#   4. Pentaho container starts → runs extra-entrypoint.sh
#      → Fetches credentials from Vault → injects into context.xml
#   5. Pentaho connects to Oracle using Vault credentials ✓
#
#   IMPORTANT: On clean deployment, passwords are NOT rotated automatically.
#   The default password "password" is used to ensure Oracle and Vault match.
#   After verifying the deployment works, run rotate-secrets.sh to secure
#   the passwords:
#
#     ./scripts/rotate-secrets.sh
#
# SUBSEQUENT RESTARTS:
#   - If generated-passwords.json exists, those passwords are used
#   - This maintains consistency after password rotation
#   - Vault is unsealed automatically using stored keys
#
# FILES CREATED:
#   /vault/data/vault-keys.json      - Unseal keys and root token (SECURE THIS!)
#   /vault/data/approle-creds.json   - AppRole credentials for Pentaho
#   /vault/data/generated-passwords.json - Current passwords (after rotation)
#
# SECURITY NOTES:
#   - In production, distribute unseal keys to different people
#   - Delete vault-keys.json after distributing keys
#   - Enable audit logging
#   - Use auto-unseal with cloud KMS in production
#
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
VAULT_KEYS_FILE="/vault/data/vault-keys.json"
GENERATED_PASSWORDS_FILE="/vault/data/generated-passwords.json"
APPROLE_CREDS_FILE="/vault/data/approle-creds.json"
MAX_RETRIES=30
RETRY_INTERVAL=2

# Default passwords - MUST match db_init_oracle/*.sql scripts
# These are the passwords Oracle users are created with
DEFAULT_DB_PASSWORD="password"

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Generate a secure random password
# Usage: generate_password [length]
# Default length: 24 characters
# Format: alphanumeric + required complexity suffix (Aa1!)
generate_password() {
    local length=${1:-24}
    local base=$(head -c 100 /dev/urandom | tr -dc 'A-Za-z0-9' | head -c $((length - 4)))
    echo "${base}Aa1!"
}

# Wait for Vault to be ready with exponential backoff
wait_for_vault() {
    local retries=0
    echo "Waiting for Vault to be ready..."
    until curl -s "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; do
        retries=$((retries + 1))
        if [ $retries -ge $MAX_RETRIES ]; then
            echo "ERROR: Vault did not become ready after $MAX_RETRIES attempts"
            exit 1
        fi
        echo "  Attempt $retries/$MAX_RETRIES - Vault not ready, retrying in ${RETRY_INTERVAL}s..."
        sleep $RETRY_INTERVAL
    done
    echo "Vault is ready"
}

# Mask sensitive data for safe display in logs
# Shows first 4 and last 4 characters only
mask_token() {
    local token="$1"
    local visible_chars=4
    if [ ${#token} -gt $((visible_chars * 2)) ]; then
        echo "${token:0:$visible_chars}...${token: -$visible_chars}"
    else
        echo "****"
    fi
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

echo "============================================"
echo " Vault Initialization Script"
echo " Database: Oracle"
echo "============================================"

wait_for_vault

# -----------------------------------------------------------------------------
# Step 1: Initialize Vault (first run only)
# -----------------------------------------------------------------------------
INIT_STATUS=$(curl -s "${VAULT_ADDR}/v1/sys/init" | jq -r '.initialized')

if [ "$INIT_STATUS" = "false" ]; then
    echo ""
    echo ">>> Initializing Vault (first run)..."
    echo "    Creating 5 unseal key shares with threshold of 3"

    # Initialize Vault with Shamir's secret sharing
    # 5 keys total, need 3 to unseal
    INIT_RESPONSE=$(curl -s --request POST \
        --data '{"secret_shares": 5, "secret_threshold": 3}' \
        "${VAULT_ADDR}/v1/sys/init")

    # Save keys securely
    echo "$INIT_RESPONSE" > "$VAULT_KEYS_FILE"
    chmod 600 "$VAULT_KEYS_FILE"

    echo "    Vault initialized successfully"
    echo "    Keys saved to: $VAULT_KEYS_FILE"
    echo ""
    echo "    ⚠️  SECURITY WARNING:"
    echo "    In production, distribute unseal keys to different trusted parties"
    echo "    and delete $VAULT_KEYS_FILE after distributing."
else
    echo ""
    echo ">>> Vault already initialized"
fi

# -----------------------------------------------------------------------------
# Step 2: Unseal Vault
# -----------------------------------------------------------------------------
SEAL_STATUS=$(curl -s "${VAULT_ADDR}/v1/sys/seal-status" | jq -r '.sealed')

if [ "$SEAL_STATUS" = "true" ]; then
    echo ""
    echo ">>> Unsealing Vault..."

    if [ -f "$VAULT_KEYS_FILE" ]; then
        # Get the first 3 unseal keys (threshold is 3)
        KEYS=$(jq -r '.keys // .keys_base64 // [] | .[]' "$VAULT_KEYS_FILE" 2>/dev/null | head -3)

        if [ -z "$KEYS" ]; then
            echo "ERROR: No unseal keys found in $VAULT_KEYS_FILE"
            cat "$VAULT_KEYS_FILE"
            exit 1
        fi

        # Apply each unseal key
        KEY_NUM=1
        for KEY in $KEYS; do
            echo "    Applying unseal key $KEY_NUM/3..."
            curl -s --request POST \
                --data "{\"key\": \"$KEY\"}" \
                "${VAULT_ADDR}/v1/sys/unseal" > /dev/null
            KEY_NUM=$((KEY_NUM + 1))
        done

        echo "    Vault unsealed successfully"
    else
        echo "ERROR: Cannot unseal Vault - keys file not found at $VAULT_KEYS_FILE"
        exit 1
    fi
else
    echo ""
    echo ">>> Vault is already unsealed"
fi

# Get root token for subsequent operations
ROOT_TOKEN=$(jq -r '.root_token' "$VAULT_KEYS_FILE")

# -----------------------------------------------------------------------------
# Step 3: Enable KV Secrets Engine v2
# -----------------------------------------------------------------------------
echo ""
echo ">>> Checking secrets engine..."

SECRETS_ENGINES=$(curl -s --header "X-Vault-Token: $ROOT_TOKEN" \
    "${VAULT_ADDR}/v1/sys/mounts" | jq -r 'keys[]')

if ! echo "$SECRETS_ENGINES" | grep -q "^secret/$"; then
    echo "    Enabling KV secrets engine v2 at path 'secret/'..."
    curl -s --header "X-Vault-Token: $ROOT_TOKEN" \
        --request POST \
        --data '{"type": "kv", "options": {"version": "2"}}' \
        "${VAULT_ADDR}/v1/sys/mounts/secret"
    echo "    KV secrets engine enabled"
else
    echo "    KV secrets engine already enabled"
fi

# -----------------------------------------------------------------------------
# Step 4: Determine which passwords to use
# -----------------------------------------------------------------------------
# On CLEAN deployment: Use default passwords (matches Oracle init scripts)
# After ROTATION: Use previously rotated passwords from generated-passwords.json
# -----------------------------------------------------------------------------
echo ""
echo ">>> Determining database credentials..."

if [ -f "$GENERATED_PASSWORDS_FILE" ]; then
    # Passwords were previously rotated - use those
    echo "    Found existing passwords (previously rotated)"
    echo "    Loading from: $GENERATED_PASSWORDS_FILE"

    JCR_PASSWORD=$(jq -r '.jcr_password' "$GENERATED_PASSWORDS_FILE")
    PENTAHO_PASSWORD=$(jq -r '.pentaho_password' "$GENERATED_PASSWORDS_FILE")
    HIBUSER_PASSWORD=$(jq -r '.hibuser_password' "$GENERATED_PASSWORDS_FILE")

    PASSWORDS_SOURCE="rotated"
else
    # Clean deployment - use default passwords that match Oracle init scripts
    # This ensures Pentaho can connect immediately after deployment
    echo "    Clean deployment detected"
    echo "    Using default passwords (matches Oracle init scripts)"
    echo ""
    echo "    ⚠️  SECURITY NOTICE:"
    echo "    Default passwords are in use. After verifying the deployment,"
    echo "    rotate passwords for security:"
    echo ""
    echo "        ./scripts/rotate-secrets.sh"
    echo ""

    JCR_PASSWORD="$DEFAULT_DB_PASSWORD"
    PENTAHO_PASSWORD="$DEFAULT_DB_PASSWORD"
    HIBUSER_PASSWORD="$DEFAULT_DB_PASSWORD"

    PASSWORDS_SOURCE="default"
fi

# -----------------------------------------------------------------------------
# Step 5: Store credentials in Vault
# -----------------------------------------------------------------------------
echo ">>> Storing Oracle credentials in Vault..."
echo "    Path: secret/data/pentaho/oracle"

curl -s --header "X-Vault-Token: $ROOT_TOKEN" \
    --request POST \
    --data "{
        \"data\": {
            \"oracle_password\": \"${ORACLE_PASSWORD:-password}\",
            \"jcr_user\": \"jcr_user\",
            \"jcr_password\": \"$JCR_PASSWORD\",
            \"pentaho_user\": \"pentaho_user\",
            \"pentaho_password\": \"$PENTAHO_PASSWORD\",
            \"hibuser\": \"hibuser\",
            \"hibuser_password\": \"$HIBUSER_PASSWORD\",
            \"jdbc_url\": \"jdbc:oracle:thin:@repository:1521/FREEPDB1\",
            \"passwords_source\": \"$PASSWORDS_SOURCE\",
            \"updated_at\": \"$(date -Iseconds)\"
        }
    }" \
    "${VAULT_ADDR}/v1/secret/data/pentaho/oracle"

# Verify secrets were stored
echo "    Verifying secrets storage..."
VERIFY_RESULT=$(curl -s --header "X-Vault-Token: $ROOT_TOKEN" \
    "${VAULT_ADDR}/v1/secret/data/pentaho/oracle" | jq -r '.data.data.pentaho_user // "FAILED"')

if [ "$VERIFY_RESULT" = "FAILED" ] || [ -z "$VERIFY_RESULT" ]; then
    echo "ERROR: Failed to verify secrets were stored correctly"
    exit 1
fi
echo "    Secrets stored and verified ✓"

# -----------------------------------------------------------------------------
# Step 6: Configure AppRole Authentication
# -----------------------------------------------------------------------------
# AppRole allows Pentaho to authenticate with Vault without human intervention
# It uses a role_id (like username) and secret_id (like password)
# -----------------------------------------------------------------------------
echo ""
echo ">>> Configuring AppRole authentication..."

# Enable AppRole auth method (ignore error if already enabled)
curl -s --header "X-Vault-Token: $ROOT_TOKEN" \
    --request POST \
    --data '{"type": "approle"}' \
    "${VAULT_ADDR}/v1/sys/auth/approle" 2>/dev/null || true

# Create policy that allows reading Pentaho secrets
echo "    Creating pentaho-policy..."
curl -s --header "X-Vault-Token: $ROOT_TOKEN" \
    --request PUT \
    --data "{\"policy\": \"path \\\"secret/data/pentaho/*\\\" { capabilities = [\\\"read\\\", \\\"list\\\"] }\"}" \
    "${VAULT_ADDR}/v1/sys/policies/acl/pentaho-policy"

# Create AppRole for Pentaho
# token_ttl: How long the token is valid (1 hour)
# token_max_ttl: Maximum lifetime even with renewals (4 hours)
echo "    Creating pentaho AppRole..."
curl -s --header "X-Vault-Token: $ROOT_TOKEN" \
    --request POST \
    --data '{"policies": ["pentaho-policy"], "token_ttl": "1h", "token_max_ttl": "4h"}' \
    "${VAULT_ADDR}/v1/auth/approle/role/pentaho"

# Get Role ID (static identifier)
ROLE_ID=$(curl -s --header "X-Vault-Token: $ROOT_TOKEN" \
    "${VAULT_ADDR}/v1/auth/approle/role/pentaho/role-id" | jq -r '.data.role_id')

# Generate Secret ID (should be rotated periodically in production)
SECRET_ID=$(curl -s --header "X-Vault-Token: $ROOT_TOKEN" \
    --request POST \
    "${VAULT_ADDR}/v1/auth/approle/role/pentaho/secret-id" | jq -r '.data.secret_id')

# -----------------------------------------------------------------------------
# Step 7: Save AppRole credentials for Pentaho
# -----------------------------------------------------------------------------
# The Pentaho container reads this file during startup
# chmod 644 allows the pentaho user (UID 5000) to read it
# -----------------------------------------------------------------------------
echo ""
echo ">>> Saving AppRole credentials..."

echo "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" > "$APPROLE_CREDS_FILE"
chmod 644 "$APPROLE_CREDS_FILE"  # Readable by pentaho container user

echo "    Saved to: $APPROLE_CREDS_FILE"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo ""
echo "============================================"
echo " Vault Initialization Complete!"
echo "============================================"
echo ""
echo "Credentials stored:"
echo "  Root Token:  $(mask_token "$ROOT_TOKEN")"
echo "  Role ID:     $(mask_token "$ROLE_ID")"
echo "  Secret ID:   $(mask_token "$SECRET_ID")"
echo ""
echo "Files created:"
echo "  Vault keys:     $VAULT_KEYS_FILE"
echo "  AppRole creds:  $APPROLE_CREDS_FILE"
if [ -f "$GENERATED_PASSWORDS_FILE" ]; then
echo "  Passwords:      $GENERATED_PASSWORDS_FILE"
fi
echo ""
if [ "$PASSWORDS_SOURCE" = "default" ]; then
echo "⚠️  NEXT STEP: Rotate passwords after deployment verification:"
echo ""
echo "    ./scripts/rotate-secrets.sh"
echo ""
fi
echo "============================================"
