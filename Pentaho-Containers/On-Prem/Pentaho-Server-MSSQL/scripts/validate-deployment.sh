#!/bin/bash
#
# Pentaho Deployment Validation Script
# Verifies that all services are running correctly
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Load environment variables
if [ -f "../.env" ]; then
    set -a
    source ../.env
    set +a
elif [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

MSSQL_PASSWORD="${MSSQL_SA_PASSWORD:-Password123!}"
PENTAHO_HTTP_PORT="${PENTAHO_HTTP_PORT:-8090}"

echo "=========================================="
echo " Pentaho Deployment Validation"
echo "=========================================="
echo ""

# Track overall status
VALIDATION_FAILED=0

# Check 1: Docker Compose services running
echo "→ Checking Docker Compose services..."
if docker compose ps | grep -q "pentaho-mssql.*running"; then
    echo -e "${GREEN}✓ SQL Server container is running${NC}"
else
    echo -e "${RED}✗ SQL Server container is not running${NC}"
    VALIDATION_FAILED=1
fi

if docker compose ps | grep -q "pentaho-server.*running"; then
    echo -e "${GREEN}✓ Pentaho Server container is running${NC}"
else
    echo -e "${RED}✗ Pentaho Server container is not running${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# Check 2: SQL Server health
echo "→ Checking SQL Server health..."
if docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_PASSWORD" -Q "SELECT 1" -C > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SQL Server is responding to queries${NC}"
else
    echo -e "${RED}✗ SQL Server is not responding${NC}"
    VALIDATION_FAILED=1
fi

echo ""

# Check 3: Pentaho databases exist
echo "→ Checking Pentaho repository databases..."
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

# Check 4: Pentaho repository tables
echo "→ Checking Pentaho repository tables..."

# Check Jackrabbit tables
JACKRABBIT_TABLES=$(docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U jcr_user -P password -d jackrabbit -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'" -h -1 -C 2>/dev/null | tr -d '[:space:]' || echo "0")
if [ "$JACKRABBIT_TABLES" -gt 5 ]; then
    echo -e "${GREEN}✓ Jackrabbit tables exist ($JACKRABBIT_TABLES tables)${NC}"
else
    echo -e "${YELLOW}⚠ Jackrabbit tables not initialized yet (may initialize on first Pentaho startup)${NC}"
fi

# Check Quartz tables
QUARTZ_TABLES=$(docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U pentaho_user -P password -d quartz -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME LIKE 'QRTZ6_%'" -h -1 -C 2>/dev/null | tr -d '[:space:]' || echo "0")
if [ "$QUARTZ_TABLES" -gt 10 ]; then
    echo -e "${GREEN}✓ Quartz scheduler tables exist ($QUARTZ_TABLES tables)${NC}"
else
    echo -e "${YELLOW}⚠ Quartz tables not fully initialized${NC}"
fi

# Check Hibernate tables
HIBERNATE_TABLES=$(docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U hibuser -P password -d hibernate -Q "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE'" -h -1 -C 2>/dev/null | tr -d '[:space:]' || echo "0")
if [ "$HIBERNATE_TABLES" -gt 1 ]; then
    echo -e "${GREEN}✓ Hibernate tables exist ($HIBERNATE_TABLES tables)${NC}"
else
    echo -e "${YELLOW}⚠ Hibernate tables not initialized yet${NC}"
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
VOLUMES=$(docker volume ls | grep -E "pentaho_mssql_data|pentaho_solutions|pentaho_logs|pentaho_data" || true)

if echo "$VOLUMES" | grep -q "pentaho_mssql_data"; then
    echo -e "${GREEN}✓ SQL Server data volume exists${NC}"
else
    echo -e "${RED}✗ SQL Server data volume not found${NC}"
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
