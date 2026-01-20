#!/bin/bash
# =============================================================================
# Deployment Validation Script for K3s
# =============================================================================
# Validates that all Pentaho components are running correctly
#
# Usage: ./scripts/validate-deployment.sh
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="pentaho"
ERRORS=0

echo -e "${BLUE}"
echo "=============================================="
echo "  Pentaho K3s Deployment Validation"
echo "=============================================="
echo -e "${NC}"

# Function to check component
check_component() {
    local name=$1
    local check_cmd=$2

    if eval "${check_cmd}" &> /dev/null; then
        echo -e "${GREEN}✓${NC} ${name}"
        return 0
    else
        echo -e "${RED}✗${NC} ${name}"
        ((ERRORS++))
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Namespace Check
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[1/6] Checking Namespace${NC}"
check_component "Namespace 'pentaho' exists" \
    "kubectl get namespace ${NAMESPACE}"

# -----------------------------------------------------------------------------
# Pod Checks
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/6] Checking Pods${NC}"

# PostgreSQL
if kubectl get pod -l app=postgres -n ${NAMESPACE} -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running; then
    echo -e "${GREEN}✓${NC} PostgreSQL pod is running"
else
    echo -e "${RED}✗${NC} PostgreSQL pod is NOT running"
    ((ERRORS++))
fi

# Pentaho Server
if kubectl get pod -l app=pentaho-server -n ${NAMESPACE} -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running; then
    echo -e "${GREEN}✓${NC} Pentaho Server pod is running"
else
    echo -e "${YELLOW}!${NC} Pentaho Server pod is NOT running (may still be starting)"
    # Check if it's starting
    POD_STATUS=$(kubectl get pod -l app=pentaho-server -n ${NAMESPACE} -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    echo "  Current status: ${POD_STATUS}"
fi

# -----------------------------------------------------------------------------
# Service Checks
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/6] Checking Services${NC}"
check_component "PostgreSQL service" \
    "kubectl get svc postgres -n ${NAMESPACE}"
check_component "Pentaho Server service" \
    "kubectl get svc pentaho-server -n ${NAMESPACE}"

# -----------------------------------------------------------------------------
# PVC Checks
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/6] Checking PersistentVolumeClaims${NC}"

for pvc in postgres-data-pvc pentaho-data-pvc pentaho-solutions-pvc; do
    STATUS=$(kubectl get pvc ${pvc} -n ${NAMESPACE} -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    if [ "${STATUS}" = "Bound" ]; then
        echo -e "${GREEN}✓${NC} ${pvc} is Bound"
    else
        echo -e "${RED}✗${NC} ${pvc} status: ${STATUS}"
        ((ERRORS++))
    fi
done

# -----------------------------------------------------------------------------
# ConfigMap Checks
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[5/6] Checking ConfigMaps${NC}"
check_component "pentaho-config ConfigMap" \
    "kubectl get configmap pentaho-config -n ${NAMESPACE}"
check_component "postgres-init ConfigMap" \
    "kubectl get configmap postgres-init -n ${NAMESPACE}"

# -----------------------------------------------------------------------------
# Ingress Check
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[6/6] Checking Ingress${NC}"
check_component "pentaho-ingress" \
    "kubectl get ingress pentaho-ingress -n ${NAMESPACE}"

# -----------------------------------------------------------------------------
# Database Connectivity Test
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}Testing Database Connectivity${NC}"

POSTGRES_POD=$(kubectl get pod -l app=postgres -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "${POSTGRES_POD}" ]; then
    # Test database connections
    for db in jackrabbit quartz hibernate; do
        if kubectl exec ${POSTGRES_POD} -n ${NAMESPACE} -- psql -U postgres -d ${db} -c "SELECT 1" &> /dev/null; then
            echo -e "${GREEN}✓${NC} Database '${db}' accessible"
        else
            echo -e "${RED}✗${NC} Database '${db}' NOT accessible"
            ((ERRORS++))
        fi
    done
else
    echo -e "${YELLOW}!${NC} Cannot test database - PostgreSQL pod not found"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}=============================================="
echo "  Validation Summary"
echo "==============================================${NC}"

if [ ${ERRORS} -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
else
    echo -e "${RED}${ERRORS} check(s) failed${NC}"
fi

# Show access information
echo ""
echo -e "${YELLOW}Resource Overview:${NC}"
kubectl get all -n ${NAMESPACE}

echo ""
echo -e "${YELLOW}Access URLs:${NC}"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Node IP: ${NODE_IP}"
echo ""
echo "Port-forward command:"
echo "  kubectl port-forward svc/pentaho-server 8080:8080 -n pentaho"
echo ""
echo "Then access: http://localhost:8080/pentaho"

exit ${ERRORS}
