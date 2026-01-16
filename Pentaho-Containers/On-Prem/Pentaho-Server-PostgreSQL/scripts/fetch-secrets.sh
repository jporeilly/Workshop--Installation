#!/bin/bash
# Fetch secrets from Vault for Pentaho containers
# This script retrieves database credentials from Vault using AppRole authentication

set -e

VAULT_ADDR="${VAULT_ADDR:-http://vault:8200}"
APPROLE_CREDS_FILE="${APPROLE_CREDS_FILE:-/vault/data/approle-creds.json}"
SECRETS_OUTPUT="${SECRETS_OUTPUT:-/run/secrets/db-credentials}"

echo "Fetching secrets from Vault..."

# Wait for Vault to be available
until curl -s "${VAULT_ADDR}/v1/sys/health" | jq -e '.sealed == false' > /dev/null 2>&1; do
    echo "Waiting for Vault to be unsealed..."
    sleep 5
done

# Read AppRole credentials
if [ -f "$APPROLE_CREDS_FILE" ]; then
    ROLE_ID=$(jq -r '.role_id' "$APPROLE_CREDS_FILE")
    SECRET_ID=$(jq -r '.secret_id' "$APPROLE_CREDS_FILE")
else
    # Try environment variables as fallback
    ROLE_ID="${VAULT_ROLE_ID:-}"
    SECRET_ID="${VAULT_SECRET_ID:-}"
fi

if [ -z "$ROLE_ID" ] || [ -z "$SECRET_ID" ]; then
    echo "ERROR: AppRole credentials not found"
    exit 1
fi

# Authenticate with AppRole
echo "Authenticating with Vault..."
AUTH_RESPONSE=$(curl -s --request POST \
    --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
    "${VAULT_ADDR}/v1/auth/approle/login")

CLIENT_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.auth.client_token')

if [ "$CLIENT_TOKEN" = "null" ] || [ -z "$CLIENT_TOKEN" ]; then
    echo "ERROR: Failed to authenticate with Vault"
    echo "$AUTH_RESPONSE"
    exit 1
fi

# Fetch database secrets
echo "Retrieving database credentials..."
SECRETS=$(curl -s --header "X-Vault-Token: $CLIENT_TOKEN" \
    "${VAULT_ADDR}/v1/secret/data/pentaho/${DB_TYPE:-mysql}")

# Extract credentials
DB_ROOT_PASSWORD=$(echo "$SECRETS" | jq -r '.data.data.root_password')
DB_PENTAHO_USER=$(echo "$SECRETS" | jq -r '.data.data.pentaho_user')
DB_PENTAHO_PASSWORD=$(echo "$SECRETS" | jq -r '.data.data.pentaho_password')
DB_JDBC_URL=$(echo "$SECRETS" | jq -r '.data.data.jdbc_url')

# Create secrets output directory
mkdir -p "$(dirname "$SECRETS_OUTPUT")"

# Write secrets to file (can be mounted as tmpfs for security)
cat > "$SECRETS_OUTPUT" << EOF
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
DB_PENTAHO_USER=$DB_PENTAHO_USER
DB_PENTAHO_PASSWORD=$DB_PENTAHO_PASSWORD
DB_JDBC_URL=$DB_JDBC_URL
EOF

chmod 600 "$SECRETS_OUTPUT"

echo "Secrets retrieved successfully and written to $SECRETS_OUTPUT"

# Export as environment variables if requested
if [ "${EXPORT_ENV:-false}" = "true" ]; then
    export DB_ROOT_PASSWORD DB_PENTAHO_USER DB_PENTAHO_PASSWORD DB_JDBC_URL
fi
