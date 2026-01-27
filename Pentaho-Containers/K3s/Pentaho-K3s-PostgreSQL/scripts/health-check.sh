#!/bin/bash
# =============================================================================
# Pentaho K3s Health Check Script
# =============================================================================
# Quick health check for Pentaho deployment
#
# Checks:
#   - Pod status (running and ready)
#   - Database connectivity
#   - Pentaho web application responsiveness
#   - Resource usage
#
# Usage: ./scripts/health-check.sh
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="pentaho"
FAILED=0

echo -e "${BLUE}=============================================="
echo -e "  Pentaho K3s Health Check"
echo -e "==============================================${NC}\n"

# Check if namespace exists
echo -e "${YELLOW}Checking namespace...${NC}"
if kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✓ Namespace '$NAMESPACE' exists${NC}\n"
else
    echo -e "${RED}✗ Namespace '$NAMESPACE' not found${NC}\n"
    exit 1
fi

# Check pod status
echo -e "${YELLOW}Checking pod status...${NC}"
POSTGRES_READY=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
PENTAHO_READY=$(kubectl get pods -n $NAMESPACE -l app=pentaho-server -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")

if [ "$POSTGRES_READY" == "true" ]; then
    echo -e "${GREEN}✓ PostgreSQL pod is running and ready${NC}"
else
    echo -e "${RED}✗ PostgreSQL pod is not ready${NC}"
    FAILED=1
fi

if [ "$PENTAHO_READY" == "true" ]; then
    echo -e "${GREEN}✓ Pentaho Server pod is running and ready${NC}\n"
else
    echo -e "${RED}✗ Pentaho Server pod is not ready${NC}\n"
    FAILED=1
fi

# Check services
echo -e "${YELLOW}Checking services...${NC}"
if kubectl get svc postgres -n $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✓ PostgreSQL service exists${NC}"
else
    echo -e "${RED}✗ PostgreSQL service not found${NC}"
    FAILED=1
fi

if kubectl get svc pentaho-server -n $NAMESPACE &> /dev/null; then
    echo -e "${GREEN}✓ Pentaho Server service exists${NC}\n"
else
    echo -e "${RED}✗ Pentaho Server service not found${NC}\n"
    FAILED=1
fi

# Check database connectivity
echo -e "${YELLOW}Checking database connectivity...${NC}"
if kubectl exec -n $NAMESPACE deployment/postgres -- psql -U postgres -c "SELECT 1" &> /dev/null; then
    echo -e "${GREEN}✓ PostgreSQL is responding${NC}"

    # Check specific databases
    for db in jackrabbit quartz hibernate; do
        if kubectl exec -n $NAMESPACE deployment/postgres -- psql -U postgres -lqt | cut -d \| -f 1 | grep -qw $db; then
            echo -e "${GREEN}✓ Database '$db' exists${NC}"
        else
            echo -e "${RED}✗ Database '$db' not found${NC}"
            FAILED=1
        fi
    done
    echo ""
else
    echo -e "${RED}✗ Cannot connect to PostgreSQL${NC}\n"
    FAILED=1
fi

# Check Pentaho web application
echo -e "${YELLOW}Checking Pentaho web application...${NC}"
# Start port-forward in background
kubectl port-forward -n $NAMESPACE svc/pentaho-server 8080:8080 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

# Test HTTP endpoint
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/pentaho/Login 2>/dev/null || echo "000")

# Cleanup port-forward
kill $PF_PID 2>/dev/null

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ Pentaho login page is accessible (HTTP $HTTP_CODE)${NC}\n"
else
    echo -e "${RED}✗ Pentaho login page returned HTTP $HTTP_CODE${NC}\n"
    FAILED=1
fi

# Show resource usage
echo -e "${YELLOW}Resource usage:${NC}"
kubectl top pods -n $NAMESPACE 2>/dev/null || echo -e "${YELLOW}(Metrics server not available)${NC}"
echo ""

# Summary
echo -e "${BLUE}=============================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}  ✓ All health checks passed!"
    echo -e "${BLUE}==============================================${NC}\n"
    echo -e "Access Pentaho at: ${GREEN}http://localhost:8080/pentaho${NC}"
    echo -e "Port-forward command: ${BLUE}kubectl port-forward -n pentaho svc/pentaho-server 8080:8080${NC}\n"
    exit 0
else
    echo -e "${RED}  ✗ Some health checks failed"
    echo -e "${BLUE}==============================================${NC}\n"
    echo -e "Run for details: ${YELLOW}kubectl get all -n pentaho${NC}"
    echo -e "Check logs: ${YELLOW}kubectl logs -n pentaho deployment/pentaho-server${NC}\n"
    exit 1
fi
