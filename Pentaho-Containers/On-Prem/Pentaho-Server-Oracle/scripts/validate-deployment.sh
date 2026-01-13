#!/bin/bash
# =============================================================================
# Pentaho Server Deployment Validation Script (Oracle Repository)
# =============================================================================
#
# Validates that all components of the Pentaho Server deployment are working
#
# Usage:
#   ./scripts/validate-deployment.sh
#
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Load environment
if [ -f ".env" ]; then
    source .env
fi

PENTAHO_HTTP_PORT="${PENTAHO_HTTP_PORT:-8090}"
ORACLE_PORT="${ORACLE_PORT:-1521}"
ORACLE_PASSWORD="${ORACLE_PASSWORD:-password}"

echo "=========================================="
echo " Pentaho Server Deployment Validation"
echo " (Oracle Repository)"
echo "=========================================="
echo ""

CHECKS_PASSED=0
CHECKS_FAILED=0

check_pass() {
    echo -e "${GREEN}✓ $1${NC}"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}✗ $1${NC}"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# =============================================================================
# Container Checks
# =============================================================================
echo -e "${BLUE}→ Checking containers...${NC}"

# Check 1: Oracle container
if docker compose ps | grep -q "pentaho-oracle.*running"; then
    check_pass "Oracle container is running"
else
    check_fail "Oracle container is not running"
fi

# Check 2: Pentaho container
if docker compose ps | grep -q "pentaho-server.*running"; then
    check_pass "Pentaho Server container is running"
else
    check_fail "Pentaho Server container is not running"
fi

# Check 3: Oracle health
if docker compose ps oracle | grep -q "healthy"; then
    check_pass "Oracle is healthy"
else
    check_warn "Oracle health check not passing"
fi

# Check 4: Pentaho health
if docker compose ps pentaho-server | grep -q "healthy"; then
    check_pass "Pentaho Server is healthy"
else
    check_warn "Pentaho Server health check not passing (may still be starting)"
fi

echo ""

# =============================================================================
# Database Checks
# =============================================================================
echo -e "${BLUE}→ Checking Oracle database...${NC}"

# Check 5: Oracle connection
if docker exec pentaho-oracle sqlplus -s hibuser/password@//localhost:1521/FREEPDB1 <<< "SELECT 1 FROM DUAL; EXIT;" &>/dev/null; then
    check_pass "Oracle database connection successful"
else
    check_fail "Cannot connect to Oracle database"
fi

# Check 6: Pentaho users exist
for user in JCR_USER PENTAHO_USER HIBUSER; do
    if docker exec pentaho-oracle sqlplus -s system/${ORACLE_PASSWORD}@//localhost:1521/FREEPDB1 <<< "SELECT username FROM dba_users WHERE username='$user'; EXIT;" 2>/dev/null | grep -q "$user"; then
        check_pass "Oracle user $user exists"
    else
        check_fail "Oracle user $user not found"
    fi
done

# Check 7: Quartz tables exist
if docker exec pentaho-oracle sqlplus -s pentaho_user/password@//localhost:1521/FREEPDB1 <<< "SELECT table_name FROM user_tables WHERE table_name LIKE 'QRTZ6%'; EXIT;" 2>/dev/null | grep -q "QRTZ6"; then
    check_pass "Quartz scheduler tables exist"
else
    check_warn "Quartz tables not found (may be created on first Pentaho start)"
fi

echo ""

# =============================================================================
# HTTP Endpoint Checks
# =============================================================================
echo -e "${BLUE}→ Checking HTTP endpoints...${NC}"

# Check 8: Pentaho login page
if curl -f -s -o /dev/null "http://localhost:$PENTAHO_HTTP_PORT/pentaho/Login"; then
    check_pass "Pentaho login page is accessible"
else
    check_fail "Pentaho login page is not accessible"
fi

# Check 9: Pentaho API
if curl -f -s -o /dev/null "http://localhost:$PENTAHO_HTTP_PORT/pentaho/api/system/version" -u admin:password 2>/dev/null; then
    check_pass "Pentaho API is responding"
else
    check_warn "Pentaho API not responding (may require authentication)"
fi

echo ""

# =============================================================================
# Volume Checks
# =============================================================================
echo -e "${BLUE}→ Checking Docker volumes...${NC}"

# Check 10: Oracle data volume
if docker volume ls | grep -q "pentaho_oracle_data"; then
    check_pass "Oracle data volume exists"
else
    check_fail "Oracle data volume not found"
fi

# Check 11: Pentaho solutions volume
if docker volume ls | grep -q "pentaho_solutions"; then
    check_pass "Pentaho solutions volume exists"
else
    check_fail "Pentaho solutions volume not found"
fi

# Check 12: Pentaho data volume
if docker volume ls | grep -q "pentaho_data"; then
    check_pass "Pentaho data volume exists"
else
    check_fail "Pentaho data volume not found"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "=========================================="
echo " Validation Summary"
echo "=========================================="
echo ""
echo -e "  ${GREEN}Passed:${NC} $CHECKS_PASSED"
echo -e "  ${RED}Failed:${NC} $CHECKS_FAILED"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "You can now access:"
    echo "  Pentaho: http://localhost:$PENTAHO_HTTP_PORT/pentaho (admin/password)"
    exit 0
else
    echo -e "${RED}Some checks failed. Please review the output above.${NC}"
    echo ""
    echo "Troubleshooting commands:"
    echo "  View Oracle logs:   docker compose logs oracle"
    echo "  View Pentaho logs:  docker compose logs pentaho-server"
    echo "  Restart services:   docker compose restart"
    exit 1
fi
