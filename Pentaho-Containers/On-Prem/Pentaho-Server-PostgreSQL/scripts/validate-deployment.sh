#!/bin/bash
#
# Pentaho Deployment Validation Script (PostgreSQL)
# Verifies that all services are running correctly
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-password}"
PENTAHO_HTTP_PORT="${PENTAHO_HTTP_PORT:-8090}"

echo "=========================================="
echo " Pentaho Deployment Validation"
echo " (PostgreSQL Edition)"
echo "=========================================="
echo ""

# Track overall status
VALIDATION_FAILED=0

# Check 1: Docker Compose services running
echo "→ Checking Docker Compose services..."
if docker compose ps | grep -q "pentaho-postgres.*running"; then
    echo -e "${GREEN}✓ PostgreSQL container is running${NC}"
else
    echo -e "${RED}✗ PostgreSQL container is not running${NC}"
    VALIDATION_FAILED=1
fi

if docker compose ps | grep -q "pentaho-server.*running"; then
    echo -e "${GREEN}✓ Pentaho Server container is running${NC}"
else
    echo -e "${RED}✗ Pentaho Server container is not running${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# Check 2: PostgreSQL health
echo "→ Checking PostgreSQL health..."
if docker exec pentaho-postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL is responding${NC}"
else
    echo -e "${RED}✗ PostgreSQL is not responding${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# Check 3: Pentaho databases exist
echo "→ Checking Pentaho repository databases..."
DATABASES=$(docker exec pentaho-postgres psql -U postgres -c "SELECT datname FROM pg_database;" 2>/dev/null | grep -E "jackrabbit|quartz|hibernate" || true)

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

# Check 4: Pentaho repository tables
echo "→ Checking Pentaho repository tables..."
JACKRABBIT_TABLES=$(docker exec pentaho-postgres psql -U jcr_user -d jackrabbit -c "\dt" 2>/dev/null | wc -l || echo "0")
if [ "$JACKRABBIT_TABLES" -gt 2 ]; then
    echo -e "${GREEN}✓ Jackrabbit tables exist ($JACKRABBIT_TABLES entries)${NC}"
else
    echo -e "${YELLOW}⚠ Jackrabbit tables not initialized yet (may initialize on first Pentaho startup)${NC}"
fi

QUARTZ_TABLES=$(docker exec pentaho-postgres psql -U pentaho_user -d quartz -c "\dt" 2>/dev/null | grep -c "qrtz6_" || echo "0")
if [ "$QUARTZ_TABLES" -gt 0 ]; then
    echo -e "${GREEN}✓ Quartz scheduler tables exist ($QUARTZ_TABLES tables)${NC}"
else
    echo -e "${RED}✗ Quartz tables not found${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# Check 5: Pentaho Server HTTP endpoint
echo "→ Checking Pentaho Server endpoints..."
if curl -f -s -o /dev/null -w "%{http_code}" "http://localhost:$PENTAHO_HTTP_PORT/pentaho/api/system/version" | grep -q "200"; then
    echo -e "${GREEN}✓ Pentaho API is responding (http://localhost:$PENTAHO_HTTP_PORT)${NC}"
    VERSION=$(curl -s "http://localhost:$PENTAHO_HTTP_PORT/pentaho/api/system/version" 2>/dev/null || echo "unknown")
    echo "  Version: $VERSION"
else
    echo -e "${RED}✗ Pentaho API is not responding${NC}"
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

# Check 6: Docker volumes
echo "→ Checking Docker volumes..."
VOLUMES=$(docker volume ls | grep -E "pentaho_postgres_data|pentaho_solutions|pentaho_data" || true)

if echo "$VOLUMES" | grep -q "pentaho_postgres_data"; then
    echo -e "${GREEN}✓ PostgreSQL data volume exists${NC}"
else
    echo -e "${RED}✗ PostgreSQL data volume not found${NC}"
    VALIDATION_FAILED=1
fi

if echo "$VOLUMES" | grep -q "pentaho_solutions"; then
    echo -e "${GREEN}✓ Pentaho solutions volume exists${NC}"
else
    echo -e "${RED}✗ Pentaho solutions volume not found${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# Summary
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
