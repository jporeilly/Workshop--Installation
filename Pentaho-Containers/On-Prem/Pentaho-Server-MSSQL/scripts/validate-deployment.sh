#!/bin/bash
# =============================================================================
# Pentaho Deployment Validation Script
# =============================================================================
# Deployment: Pentaho Server with Microsoft SQL Server
#
# PURPOSE:
#   This script validates that all components of the Pentaho deployment are
#   working correctly. It checks Docker containers, database connectivity,
#   Vault status, and application endpoints.
#
# WHAT IT CHECKS:
#   1. Docker Compose services are running
#   2. Vault is initialized and accessible
#   3. Vault secrets are configured correctly
#   4. SQL Server is responding and databases exist
#   5. Pentaho repository tables are created
#   6. Pentaho web endpoints are accessible
#   7. Docker volumes exist
#
# USAGE:
#   ./scripts/validate-deployment.sh
#
# RUN AFTER:
#   - docker compose up -d (first deployment)
#   - docker compose restart (after changes)
#   - ./scripts/rotate-secrets.sh (after password rotation)
#
# SECURITY NOTE:
#   This script displays Vault secrets and then seals Vault for security.
#   Vault should remain sealed at rest in production environments.
#
# =============================================================================

set -uo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Determine script location and load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    source "$PROJECT_DIR/.env"
    set +a
fi

# Configuration defaults
MSSQL_PASSWORD="${MSSQL_SA_PASSWORD:-Password123!}"
PENTAHO_HTTP_PORT="${PENTAHO_HTTP_PORT:-8090}"
VAULT_PORT="${VAULT_PORT:-8200}"

# Password rotation policy (days)
ROTATION_INTERVAL_DAYS=90

# Track validation status
VALIDATION_FAILED=0

# -----------------------------------------------------------------------------
# Main Validation Script
# -----------------------------------------------------------------------------

echo "============================================"
echo " Pentaho Deployment Validation"
echo " Database: Microsoft SQL Server"
echo "============================================"
echo ""

# =============================================================================
# Check 1: Docker Compose Services
# =============================================================================
echo -e "${BLUE}→ Checking Docker Compose services...${NC}"

cd "$PROJECT_DIR"

# Check SQL Server container
if docker compose ps 2>/dev/null | grep -q "pentaho-mssql.*Up"; then
    echo -e "${GREEN}✓ SQL Server container is running${NC}"
else
    echo -e "${RED}✗ SQL Server container is not running${NC}"
    VALIDATION_FAILED=1
fi

# Check Pentaho Server container
if docker compose ps 2>/dev/null | grep -q "pentaho-server.*Up"; then
    echo -e "${GREEN}✓ Pentaho Server container is running${NC}"
else
    echo -e "${RED}✗ Pentaho Server container is not running${NC}"
    VALIDATION_FAILED=1
fi

# Check Vault container
if docker compose ps 2>/dev/null | grep -q "pentaho-vault.*Up"; then
    echo -e "${GREEN}✓ Vault container is running${NC}"
else
    echo -e "${RED}✗ Vault container is not running${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# =============================================================================
# Check 2: Vault Status
# =============================================================================
echo -e "${BLUE}→ Checking Vault status...${NC}"

# Query Vault health endpoint
VAULT_STATUS=$(curl -s "http://localhost:$VAULT_PORT/v1/sys/health" 2>/dev/null || echo "{}")
VAULT_SEALED=$(echo "$VAULT_STATUS" | jq -r 'if .sealed == null then "unknown" else .sealed | tostring end' 2>/dev/null || echo "unknown")
VAULT_INIT=$(echo "$VAULT_STATUS" | jq -r 'if .initialized == null then "unknown" else .initialized | tostring end' 2>/dev/null || echo "unknown")

if [ "$VAULT_INIT" = "true" ]; then
    echo -e "${GREEN}✓ Vault is initialized${NC}"
else
    echo -e "${RED}✗ Vault is not initialized${NC}"
    echo "  Run: docker compose up vault-init"
    VALIDATION_FAILED=1
fi

if [ "$VAULT_SEALED" = "false" ]; then
    echo -e "${GREEN}✓ Vault is unsealed${NC}"
else
    echo -e "${YELLOW}⚠ Vault is sealed${NC}"
    echo "  Note: In production, Vault should remain sealed at rest."
    echo "  Run 'docker compose up vault-init' to unseal when needed."
fi

# =============================================================================
# Check 3: Vault Secrets and Rotation Status
# =============================================================================
# Only check if Vault is unsealed
if [ "$VAULT_SEALED" = "false" ]; then
    echo ""
    echo -e "${BLUE}→ Checking Vault secrets and rotation status...${NC}"

    APPROLE_CREDS="/vault/data/approle-creds.json"
    if docker exec pentaho-vault test -f "$APPROLE_CREDS" 2>/dev/null; then
        # Extract AppRole credentials
        ROLE_ID=$(docker exec pentaho-vault cat "$APPROLE_CREDS" 2>/dev/null | jq -r '.role_id // ""')
        SECRET_ID=$(docker exec pentaho-vault cat "$APPROLE_CREDS" 2>/dev/null | jq -r '.secret_id // ""')

        if [ -n "$ROLE_ID" ] && [ -n "$SECRET_ID" ]; then
            # Authenticate with AppRole
            TOKEN_RESPONSE=$(curl -s --request POST \
                --data "{\"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\"}" \
                "http://localhost:$VAULT_PORT/v1/auth/approle/login" 2>/dev/null || echo "{}")
            CLIENT_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.auth.client_token // ""' 2>/dev/null || echo "")

            if [ -n "$CLIENT_TOKEN" ]; then
                # Fetch secrets
                SECRETS_CHECK=$(curl -s --header "X-Vault-Token: $CLIENT_TOKEN" \
                    "http://localhost:$VAULT_PORT/v1/secret/data/pentaho/mssql" 2>/dev/null || echo "{}")
                PENTAHO_USER=$(echo "$SECRETS_CHECK" | jq -r '.data.data.pentaho_user // ""' 2>/dev/null || echo "")

                if [ -n "$PENTAHO_USER" ]; then
                    echo -e "${GREEN}✓ Vault secrets are accessible${NC}"

                    # Extract secret metadata
                    JCR_USER=$(echo "$SECRETS_CHECK" | jq -r '.data.data.jcr_user // "N/A"')
                    JCR_PASS=$(echo "$SECRETS_CHECK" | jq -r '.data.data.jcr_password // "N/A"')
                    PENTAHO_PASS=$(echo "$SECRETS_CHECK" | jq -r '.data.data.pentaho_password // "N/A"')
                    HIBUSER=$(echo "$SECRETS_CHECK" | jq -r '.data.data.hibuser // "N/A"')
                    HIBUSER_PASS=$(echo "$SECRETS_CHECK" | jq -r '.data.data.hibuser_password // "N/A"')
                    PASSWORDS_SOURCE=$(echo "$SECRETS_CHECK" | jq -r '.data.data.passwords_source // "unknown"')
                    ROTATED_AT=$(echo "$SECRETS_CHECK" | jq -r '.data.data.rotated_at // .data.data.updated_at // ""')
                    SECRET_VERSION=$(echo "$SECRETS_CHECK" | jq -r '.data.metadata.version // "1"')

                    # Display secrets
                    echo ""
                    echo "  Secrets stored in Vault (secret/pentaho/mssql):"
                    echo "  ┌──────────────────────────────────────────────────────"
                    echo "  │ jcr_user:          $JCR_USER"
                    echo "  │ jcr_password:      $JCR_PASS"
                    echo "  │ pentaho_user:      $PENTAHO_USER"
                    echo "  │ pentaho_password:  $PENTAHO_PASS"
                    echo "  │ hibuser:           $HIBUSER"
                    echo "  │ hibuser_password:  $HIBUSER_PASS"
                    echo "  └──────────────────────────────────────────────────────"

                    # Display rotation status
                    echo ""
                    echo -e "${CYAN}  Password Rotation Status:${NC}"
                    echo "  ┌──────────────────────────────────────────────────────"
                    echo "  │ Secret Version:    $SECRET_VERSION"
                    echo "  │ Password Source:   $PASSWORDS_SOURCE"

                    if [ "$PASSWORDS_SOURCE" = "default" ]; then
                        echo -e "  │ ${YELLOW}⚠ WARNING: Using default passwords!${NC}"
                        echo "  │"
                        echo "  │ Default passwords are insecure. Rotate them now:"
                        echo "  │   ./scripts/rotate-secrets.sh"
                        echo "  │"
                        echo "  │ Next Rotation:     IMMEDIATE (security risk)"
                    elif [ -n "$ROTATED_AT" ]; then
                        # Calculate days since rotation
                        ROTATED_EPOCH=$(date -d "$ROTATED_AT" +%s 2>/dev/null || echo "0")
                        CURRENT_EPOCH=$(date +%s)
                        DAYS_SINCE_ROTATION=$(( (CURRENT_EPOCH - ROTATED_EPOCH) / 86400 ))
                        DAYS_UNTIL_ROTATION=$(( ROTATION_INTERVAL_DAYS - DAYS_SINCE_ROTATION ))

                        echo "  │ Last Rotated:      $ROTATED_AT"
                        echo "  │ Days Since:        $DAYS_SINCE_ROTATION days"
                        echo "  │ Rotation Policy:   Every $ROTATION_INTERVAL_DAYS days"

                        if [ $DAYS_UNTIL_ROTATION -le 0 ]; then
                            echo -e "  │ ${RED}⚠ OVERDUE: Rotation was due $((DAYS_UNTIL_ROTATION * -1)) days ago${NC}"
                            echo "  │ Next Rotation:     NOW (overdue)"
                        elif [ $DAYS_UNTIL_ROTATION -le 14 ]; then
                            echo -e "  │ ${YELLOW}⚠ Due Soon: $DAYS_UNTIL_ROTATION days remaining${NC}"
                            NEXT_DATE=$(date -d "+$DAYS_UNTIL_ROTATION days" +%Y-%m-%d 2>/dev/null || echo "soon")
                            echo "  │ Next Rotation:     $NEXT_DATE"
                        else
                            NEXT_DATE=$(date -d "+$DAYS_UNTIL_ROTATION days" +%Y-%m-%d 2>/dev/null || echo "in $DAYS_UNTIL_ROTATION days")
                            echo -e "  │ ${GREEN}✓ On Schedule${NC}"
                            echo "  │ Next Rotation:     $NEXT_DATE ($DAYS_UNTIL_ROTATION days)"
                        fi
                    else
                        echo "  │ Last Rotated:      Unknown"
                        echo "  │ Next Rotation:     Unknown (consider rotating soon)"
                    fi

                    echo "  │"
                    echo "  │ To rotate passwords:"
                    echo "  │   ./scripts/rotate-secrets.sh"
                    echo "  └──────────────────────────────────────────────────────"

                    # Seal Vault after displaying secrets
                    echo ""
                    echo -e "${BLUE}→ Sealing Vault for security...${NC}"
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
# Check 4: SQL Server Health
# =============================================================================
echo -e "${BLUE}→ Checking SQL Server health...${NC}"

if docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_PASSWORD" -Q "SELECT 1" -C > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SQL Server is responding to queries${NC}"
else
    echo -e "${RED}✗ SQL Server is not responding${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# =============================================================================
# Check 5: Pentaho Repository Databases
# =============================================================================
echo -e "${BLUE}→ Checking Pentaho repository databases...${NC}"

DATABASES=$(docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_PASSWORD" -Q "SELECT name FROM sys.databases" -h -1 -C 2>/dev/null || true)

if echo "$DATABASES" | grep -q "jackrabbit"; then
    echo -e "${GREEN}✓ jackrabbit database exists${NC}"
else
    echo -e "${RED}✗ jackrabbit database not found${NC}"
    VALIDATION_FAILED=1
fi

if echo "$DATABASES" | grep -q "quartz"; then
    echo -e "${GREEN}✓ quartz database exists${NC}"
else
    echo -e "${RED}✗ quartz database not found${NC}"
    VALIDATION_FAILED=1
fi

if echo "$DATABASES" | grep -q "hibernate"; then
    echo -e "${GREEN}✓ hibernate database exists${NC}"
else
    echo -e "${RED}✗ hibernate database not found${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# =============================================================================
# Check 6: Pentaho Repository Tables
# =============================================================================
echo -e "${BLUE}→ Checking Pentaho repository tables...${NC}"

# Note: Using default password for table check since we may have just rotated
# The actual Pentaho server uses credentials from Vault
JACKRABBIT_TABLES=$(docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U jcr_user -P password -d jackrabbit -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'" -h -1 -C 2>/dev/null | tr -d '[:space:]' || echo "0")
if [ "$JACKRABBIT_TABLES" -gt 5 ]; then
    echo -e "${GREEN}✓ Jackrabbit tables exist ($JACKRABBIT_TABLES tables)${NC}"
else
    echo -e "${YELLOW}⚠ Jackrabbit tables not initialized yet${NC}"
    echo "  (Tables are created on first Pentaho startup)"
fi

QUARTZ_TABLES=$(docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U pentaho_user -P password -d quartz -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE 'QRTZ6_%'" -h -1 -C 2>/dev/null | tr -d '[:space:]' || echo "0")
if [ "$QUARTZ_TABLES" -gt 10 ]; then
    echo -e "${GREEN}✓ Quartz scheduler tables exist ($QUARTZ_TABLES tables)${NC}"
else
    echo -e "${RED}✗ Quartz tables not found${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# =============================================================================
# Check 7: Pentaho Server HTTP Endpoints
# =============================================================================
echo -e "${BLUE}→ Checking Pentaho Server endpoints...${NC}"

# Check API endpoint (returns 401 when not authenticated, which is OK)
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PENTAHO_HTTP_PORT/pentaho/api/system/version" 2>/dev/null || echo "000")
if [ "$API_STATUS" = "200" ] || [ "$API_STATUS" = "401" ]; then
    echo -e "${GREEN}✓ Pentaho API is responding (HTTP $API_STATUS)${NC}"
else
    echo -e "${RED}✗ Pentaho API is not responding (HTTP $API_STATUS)${NC}"
    echo "  Try: curl -v http://localhost:$PENTAHO_HTTP_PORT/pentaho/api/system/version"
    VALIDATION_FAILED=1
fi

# Check login page
if curl -f -s -o /dev/null "http://localhost:$PENTAHO_HTTP_PORT/pentaho/Login"; then
    echo -e "${GREEN}✓ Pentaho login page is accessible${NC}"
else
    echo -e "${RED}✗ Pentaho login page is not accessible${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# =============================================================================
# Check 8: Docker Volumes
# =============================================================================
echo -e "${BLUE}→ Checking Docker volumes...${NC}"

VOLUMES=$(docker volume ls 2>/dev/null | grep -E "pentaho.*mssql_data|pentaho.*solutions|pentaho.*data|vault_data" || true)

if echo "$VOLUMES" | grep -q "mssql_data"; then
    echo -e "${GREEN}✓ SQL Server data volume exists${NC}"
else
    echo -e "${RED}✗ SQL Server data volume not found${NC}"
    VALIDATION_FAILED=1
fi

if echo "$VOLUMES" | grep -q "solutions"; then
    echo -e "${GREEN}✓ Pentaho solutions volume exists${NC}"
else
    echo -e "${RED}✗ Pentaho solutions volume not found${NC}"
    VALIDATION_FAILED=1
fi

if echo "$VOLUMES" | grep -q "vault_data"; then
    echo -e "${GREEN}✓ Vault data volume exists${NC}"
else
    echo -e "${YELLOW}⚠ Vault data volume not found${NC}"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "============================================"
if [ $VALIDATION_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo ""
    echo "Access Pentaho:"
    echo "  URL:      http://localhost:$PENTAHO_HTTP_PORT/pentaho"
    echo "  Username: admin"
    echo "  Password: password"
    echo ""
    echo "Vault Management:"
    echo "  Unseal:   docker compose up vault-init"
    echo "  Secrets:  ./scripts/validate-deployment.sh (shows & seals)"
    echo ""
    echo "Security:"
    echo "  If using default passwords, rotate them now:"
    echo "    ./scripts/rotate-secrets.sh"
    exit 0
else
    echo -e "${RED}✗ Some validation checks failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  View logs:       docker compose logs -f"
    echo "  Check status:    docker compose ps"
    echo "  Restart:         docker compose restart"
    echo "  Full restart:    docker compose down && docker compose up -d"
    exit 1
fi
