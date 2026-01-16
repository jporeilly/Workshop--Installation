#!/bin/bash
# =============================================================================
# Pentaho Deployment Validation Script
# =============================================================================
# Deployment: Pentaho Server with Oracle Database
#
# PURPOSE:
#   Validates that all components of the Pentaho deployment are running
#   correctly and can communicate with each other. This script performs
#   comprehensive health checks on all services.
#
# WHAT THIS SCRIPT CHECKS:
#   1. Docker Compose services (Oracle, Pentaho, Vault containers)
#   2. Vault initialization and seal status
#   3. Vault secrets accessibility via AppRole authentication
#   4. Password rotation status (default vs rotated, days since rotation)
#   5. Oracle database connectivity and health
#   6. Pentaho repository users (JCR_USER, PENTAHO_USER, HIBUSER)
#   7. Pentaho repository tables (Quartz scheduler tables)
#   8. Pentaho Server HTTP endpoints (API and login page)
#   9. Docker volumes for data persistence
#
# USAGE:
#   ./scripts/validate-deployment.sh
#
# WHEN TO USE:
#   - After initial deployment to verify everything is working
#   - After password rotation to confirm connectivity
#   - When troubleshooting connectivity issues
#   - As part of regular health monitoring
#
# PASSWORD ROTATION STATUS:
#   The script checks and displays:
#   - Whether default or rotated passwords are in use
#   - When passwords were last rotated
#   - Days since last rotation
#   - Next recommended rotation date (90-day policy)
#
# SECURITY BEHAVIOR:
#   After displaying secrets information, this script automatically seals
#   Vault for security. In production, Vault should remain sealed at rest
#   and only be unsealed when needed.
#
# EXIT CODES:
#   0 - All validation checks passed
#   1 - One or more validation checks failed
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

# Load environment variables
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a
    source "$SCRIPT_DIR/../.env"
    set +a
elif [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

ORACLE_PASSWORD="${ORACLE_PASSWORD:-password}"
PENTAHO_HTTP_PORT="${PENTAHO_HTTP_PORT:-8090}"

# Password rotation policy (recommended: rotate every 90 days)
ROTATION_INTERVAL_DAYS=90

echo "=========================================="
echo " Pentaho Deployment Validation"
echo " (Oracle Edition)"
echo "=========================================="
echo ""

# Track overall status
VALIDATION_FAILED=0

# =============================================================================
# Check 1: Docker Compose services running
# =============================================================================
echo "→ Checking Docker Compose services..."
if docker compose ps | grep -q "pentaho-oracle.*Up"; then
    echo -e "${GREEN}✓ Oracle container is running${NC}"
else
    echo -e "${RED}✗ Oracle container is not running${NC}"
    VALIDATION_FAILED=1
fi

if docker compose ps | grep -q "pentaho-server.*Up"; then
    echo -e "${GREEN}✓ Pentaho Server container is running${NC}"
else
    echo -e "${RED}✗ Pentaho Server container is not running${NC}"
    VALIDATION_FAILED=1
fi

if docker compose ps | grep -q "pentaho-vault.*Up"; then
    echo -e "${GREEN}✓ Vault container is running${NC}"
else
    echo -e "${RED}✗ Vault container is not running${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# =============================================================================
# Check 2: Vault health and initialization status
# =============================================================================
echo "→ Checking Vault status..."
VAULT_STATUS=$(curl -s "http://localhost:${VAULT_PORT:-8200}/v1/sys/health" 2>/dev/null || echo "{}")
VAULT_SEALED=$(echo "$VAULT_STATUS" | jq -r 'if .sealed == null then "unknown" else .sealed | tostring end' 2>/dev/null || echo "unknown")
VAULT_INIT=$(echo "$VAULT_STATUS" | jq -r 'if .initialized == null then "unknown" else .initialized | tostring end' 2>/dev/null || echo "unknown")

if [ "$VAULT_INIT" = "true" ]; then
    echo -e "${GREEN}✓ Vault is initialized${NC}"
else
    echo -e "${RED}✗ Vault is not initialized${NC}"
    VALIDATION_FAILED=1
fi

if [ "$VAULT_SEALED" = "false" ]; then
    echo -e "${GREEN}✓ Vault is unsealed${NC}"
else
    echo -e "${YELLOW}⚠ Vault is sealed${NC}"
    echo "  Note: In production, Vault is typically sealed at rest for security."
    echo "  Run 'docker compose up vault-init' to unseal when needed."
fi

# =============================================================================
# Check 3: Vault secrets and rotation status (only if unsealed)
# =============================================================================
if [ "$VAULT_SEALED" = "false" ]; then
    # Try to read secrets using AppRole if available
    APPROLE_CREDS="/vault/data/approle-creds.json"
    if docker exec pentaho-vault test -f "$APPROLE_CREDS" 2>/dev/null; then
        ROLE_ID=$(docker exec pentaho-vault cat "$APPROLE_CREDS" 2>/dev/null | jq -r '.role_id // ""')
        SECRET_ID=$(docker exec pentaho-vault cat "$APPROLE_CREDS" 2>/dev/null | jq -r '.secret_id // ""')

        if [ -n "$ROLE_ID" ] && [ -n "$SECRET_ID" ]; then
            # Get a token using AppRole
            TOKEN_RESPONSE=$(curl -s --request POST \
                --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
                "http://localhost:${VAULT_PORT:-8200}/v1/auth/approle/login" 2>/dev/null || echo "{}")
            CLIENT_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.auth.client_token // ""' 2>/dev/null || echo "")

            if [ -n "$CLIENT_TOKEN" ]; then
                # Verify secrets exist and get metadata
                SECRETS_CHECK=$(curl -s --header "X-Vault-Token: $CLIENT_TOKEN" \
                    "http://localhost:${VAULT_PORT:-8200}/v1/secret/data/pentaho/oracle" 2>/dev/null || echo "{}")
                PENTAHO_USER=$(echo "$SECRETS_CHECK" | jq -r '.data.data.pentaho_user // ""' 2>/dev/null || echo "")

                if [ -n "$PENTAHO_USER" ]; then
                    echo -e "${GREEN}✓ Vault secrets are accessible${NC}"

                    # Extract all secret values
                    JCR_USER=$(echo "$SECRETS_CHECK" | jq -r '.data.data.jcr_user // "N/A"')
                    JCR_PASS=$(echo "$SECRETS_CHECK" | jq -r '.data.data.jcr_password // "N/A"')
                    PENTAHO_PASS=$(echo "$SECRETS_CHECK" | jq -r '.data.data.pentaho_password // "N/A"')
                    HIBUSER=$(echo "$SECRETS_CHECK" | jq -r '.data.data.hibuser // "N/A"')
                    HIBUSER_PASS=$(echo "$SECRETS_CHECK" | jq -r '.data.data.hibuser_password // "N/A"')

                    # Get rotation status information
                    SECRET_VERSION=$(echo "$SECRETS_CHECK" | jq -r '.data.metadata.version // "N/A"')
                    PASSWORDS_SOURCE=$(echo "$SECRETS_CHECK" | jq -r '.data.data.passwords_source // "unknown"')
                    UPDATED_AT=$(echo "$SECRETS_CHECK" | jq -r '.data.data.updated_at // ""')
                    ROTATED_AT=$(echo "$SECRETS_CHECK" | jq -r '.data.data.rotated_at // ""')

                    # Display secrets information
                    echo ""
                    echo "  Secrets stored in Vault (secret/pentaho/oracle):"
                    echo "    - jcr_user:          $JCR_USER"
                    echo "    - jcr_password:      $JCR_PASS"
                    echo "    - pentaho_user:      $PENTAHO_USER"
                    echo "    - pentaho_password:  $PENTAHO_PASS"
                    echo "    - hibuser:           $HIBUSER"
                    echo "    - hibuser_password:  $HIBUSER_PASS"

                    # Display rotation status
                    echo ""
                    echo -e "  ${BLUE}Password Rotation Status:${NC}"
                    echo "    - Secret Version:    $SECRET_VERSION"

                    # Show password source with color coding
                    if [ "$PASSWORDS_SOURCE" = "default" ]; then
                        echo -e "    - Password Source:   ${YELLOW}$PASSWORDS_SOURCE (INSECURE - rotate immediately!)${NC}"
                    elif [ "$PASSWORDS_SOURCE" = "rotated" ]; then
                        echo -e "    - Password Source:   ${GREEN}$PASSWORDS_SOURCE (secure)${NC}"
                    else
                        echo "    - Password Source:   $PASSWORDS_SOURCE"
                    fi

                    # Calculate days since rotation
                    if [ -n "$ROTATED_AT" ] && [ "$ROTATED_AT" != "null" ]; then
                        ROTATED_EPOCH=$(date -d "$ROTATED_AT" +%s 2>/dev/null || echo "0")
                        CURRENT_EPOCH=$(date +%s)
                        if [ "$ROTATED_EPOCH" != "0" ]; then
                            DAYS_SINCE_ROTATION=$(( (CURRENT_EPOCH - ROTATED_EPOCH) / 86400 ))
                            DAYS_UNTIL_ROTATION=$(( ROTATION_INTERVAL_DAYS - DAYS_SINCE_ROTATION ))
                            NEXT_ROTATION_DATE=$(date -d "$ROTATED_AT + $ROTATION_INTERVAL_DAYS days" +"%Y-%m-%d" 2>/dev/null || echo "N/A")

                            echo "    - Last Rotated:      $ROTATED_AT"
                            echo "    - Days Since:        $DAYS_SINCE_ROTATION days"

                            if [ $DAYS_UNTIL_ROTATION -le 0 ]; then
                                echo -e "    - Next Rotation:     ${RED}OVERDUE by $((-DAYS_UNTIL_ROTATION)) days!${NC}"
                            elif [ $DAYS_UNTIL_ROTATION -le 14 ]; then
                                echo -e "    - Next Rotation:     ${YELLOW}$NEXT_ROTATION_DATE ($DAYS_UNTIL_ROTATION days)${NC}"
                            else
                                echo -e "    - Next Rotation:     ${GREEN}$NEXT_ROTATION_DATE ($DAYS_UNTIL_ROTATION days)${NC}"
                            fi
                        fi
                    elif [ -n "$UPDATED_AT" ] && [ "$UPDATED_AT" != "null" ]; then
                        echo "    - Last Updated:      $UPDATED_AT"
                        if [ "$PASSWORDS_SOURCE" = "default" ]; then
                            echo -e "    - ${YELLOW}Run ./scripts/rotate-secrets.sh to secure passwords${NC}"
                        fi
                    fi

                    echo ""

                    # Seal Vault after displaying secrets
                    echo "→ Sealing Vault for security..."
                    ROOT_TOKEN=$(docker exec pentaho-vault cat /vault/data/vault-keys.json 2>/dev/null | jq -r '.root_token // ""')
                    if [ -n "$ROOT_TOKEN" ]; then
                        if docker exec -e VAULT_TOKEN="$ROOT_TOKEN" pentaho-vault vault operator seal > /dev/null 2>&1; then
                            echo -e "${GREEN}✓ Vault sealed successfully${NC}"
                            echo "  Note: In production, Vault should remain sealed at rest."
                            echo "  Run 'docker compose up vault-init' to unseal when needed."
                        else
                            echo -e "${YELLOW}⚠ Could not seal Vault automatically${NC}"
                        fi
                    else
                        echo -e "${YELLOW}⚠ Could not retrieve root token to seal Vault${NC}"
                    fi
                else
                    echo -e "${RED}✗ Vault secrets not found or empty${NC}"
                    VALIDATION_FAILED=1
                fi
            else
                echo -e "${YELLOW}⚠ Could not authenticate with AppRole${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ AppRole credentials not found${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Cannot verify secrets (approle-creds.json not accessible)${NC}"
    fi
fi

echo ""

# =============================================================================
# Check 4: Oracle database health
# =============================================================================
echo "→ Checking Oracle health..."
if docker exec pentaho-oracle sqlplus -s hibuser/password@//localhost:1521/FREEPDB1 <<< "SELECT 1 FROM DUAL; EXIT;" &>/dev/null; then
    echo -e "${GREEN}✓ Oracle is responding to queries${NC}"
else
    echo -e "${RED}✗ Oracle is not responding${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# =============================================================================
# Check 5: Pentaho repository users exist in Oracle
# =============================================================================
echo "→ Checking Pentaho repository users..."
for user in JCR_USER PENTAHO_USER HIBUSER; do
    if docker exec pentaho-oracle bash -c "echo \"SELECT username FROM all_users WHERE username='$user';\" | sqlplus -s system/${ORACLE_PASSWORD}@//localhost:1521/FREEPDB1" 2>/dev/null | grep -q "$user"; then
        echo -e "${GREEN}✓ $user exists${NC}"
    else
        echo -e "${RED}✗ $user not found${NC}"
        VALIDATION_FAILED=1
    fi
done

echo ""

# =============================================================================
# Check 6: Pentaho repository tables (Quartz scheduler)
# =============================================================================
echo "→ Checking Pentaho repository tables..."
if docker exec pentaho-oracle sqlplus -s pentaho_user/password@//localhost:1521/FREEPDB1 <<< "SELECT table_name FROM user_tables WHERE table_name LIKE 'QRTZ6%'; EXIT;" 2>/dev/null | grep -q "QRTZ6"; then
    echo -e "${GREEN}✓ Quartz scheduler tables exist${NC}"
else
    echo -e "${YELLOW}⚠ Quartz tables not found (may be created on first Pentaho start)${NC}"
fi

echo ""

# =============================================================================
# Check 7: Pentaho Server HTTP endpoints
# =============================================================================
echo "→ Checking Pentaho Server endpoints..."
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PENTAHO_HTTP_PORT/pentaho/api/system/version" 2>/dev/null || echo "000")
if [ "$API_STATUS" = "200" ] || [ "$API_STATUS" = "401" ]; then
    echo -e "${GREEN}✓ Pentaho API is responding (http://localhost:$PENTAHO_HTTP_PORT) [HTTP $API_STATUS]${NC}"
else
    echo -e "${RED}✗ Pentaho API is not responding (HTTP $API_STATUS)${NC}"
    echo "  Try: curl -v http://localhost:$PENTAHO_HTTP_PORT/pentaho/api/system/version"
    VALIDATION_FAILED=1
fi

if curl -f -s -o /dev/null "http://localhost:$PENTAHO_HTTP_PORT/pentaho/Login"; then
    echo -e "${GREEN}✓ Pentaho login page is accessible${NC}"
else
    echo -e "${RED}✗ Pentaho login page is not accessible${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# =============================================================================
# Check 8: Docker volumes for data persistence
# =============================================================================
echo "→ Checking Docker volumes..."
VOLUMES=$(docker volume ls | grep -E "pentaho_oracle_data|pentaho_solutions|pentaho_data|vault_data" || true)

if echo "$VOLUMES" | grep -q "pentaho_oracle_data"; then
    echo -e "${GREEN}✓ Oracle data volume exists${NC}"
else
    echo -e "${RED}✗ Oracle data volume not found${NC}"
    VALIDATION_FAILED=1
fi

if echo "$VOLUMES" | grep -q "pentaho_solutions"; then
    echo -e "${GREEN}✓ Pentaho solutions volume exists${NC}"
else
    echo -e "${RED}✗ Pentaho solutions volume not found${NC}"
    VALIDATION_FAILED=1
fi

if echo "$VOLUMES" | grep -q "vault_data"; then
    echo -e "${GREEN}✓ Vault data volume exists${NC}"
else
    echo -e "${RED}✗ Vault data volume not found${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "=========================================="
if [ $VALIDATION_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo ""
    echo "You can now access:"
    echo "  Pentaho: http://localhost:$PENTAHO_HTTP_PORT/pentaho (admin/password)"
    exit 0
else
    echo -e "${RED}✗ Some validation checks failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  View logs: docker compose logs -f"
    echo "  Check status: docker compose ps"
    echo "  Restart services: docker compose restart"
    exit 1
fi
