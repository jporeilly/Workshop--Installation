#!/bin/bash
# =============================================================================
# Deployment Validation Script for K3s
# =============================================================================
# Performs comprehensive validation of Pentaho K3s deployment to ensure all
# components are properly configured and running correctly.
#
# This script validates:
#   1. Namespace existence
#   2. Pod status (PostgreSQL and Pentaho Server)
#   3. Service availability
#   4. PersistentVolumeClaim binding status
#   5. ConfigMap presence
#   6. Ingress configuration
#   7. Database connectivity (all three Pentaho databases)
#
# Usage: ./scripts/validate-deployment.sh
#
# Exit codes:
#   0 - All validation checks passed
#   N - Number of failed checks (non-zero indicates issues)
#
# Output:
#   - Color-coded status indicators (✓ for pass, ✗ for fail)
#   - Summary of all resources in the pentaho namespace
#   - Access URLs and connection information
#
# Use Cases:
#   - Post-deployment verification
#   - Troubleshooting deployment issues
#   - Health check before making changes
#   - Continuous monitoring via cron/systemd
# =============================================================================

set -e  # Exit immediately if any command fails

# Colors for terminal output
GREEN='\033[0;32m'   # Success indicators
YELLOW='\033[1;33m'  # Warnings and section headers
RED='\033[0;31m'     # Error indicators
BLUE='\033[0;34m'    # Title and info text
NC='\033[0m'         # No Color (reset)

# Configuration
NAMESPACE="pentaho"  # Kubernetes namespace to validate
ERRORS=0             # Counter for failed checks

echo -e "${BLUE}"
echo "=============================================="
echo "  Pentaho K3s Deployment Validation"
echo "=============================================="
echo -e "${NC}"

# -----------------------------------------------------------------------------
# Helper Function: Check Component
# -----------------------------------------------------------------------------
# Generic function to test if a component exists and is properly configured
#
# Parameters:
#   $1 - Display name for the component
#   $2 - Command to execute for validation
#
# Returns:
#   0 if check passes, 1 if check fails
#   Increments ERRORS counter on failure
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
# Verifies that the 'pentaho' namespace exists in the cluster
# The namespace isolates all Pentaho resources from other applications
echo -e "\n${YELLOW}[1/6] Checking Namespace${NC}"
check_component "Namespace 'pentaho' exists" \
    "kubectl get namespace ${NAMESPACE}"

# -----------------------------------------------------------------------------
# Pod Checks
# -----------------------------------------------------------------------------
# Validates that both PostgreSQL and Pentaho Server pods are running
# Pods must be in "Running" phase for the deployment to be functional
echo -e "\n${YELLOW}[2/6] Checking Pods${NC}"

# PostgreSQL Pod
# The PostgreSQL pod hosts all three Pentaho repository databases
if kubectl get pod -l app=postgres -n ${NAMESPACE} -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q Running; then
    echo -e "${GREEN}✓${NC} PostgreSQL pod is running"
else
    echo -e "${RED}✗${NC} PostgreSQL pod is NOT running"
    ((ERRORS++))
fi

# Pentaho Server Pod
# The Pentaho Server pod runs the main application
# Note: Pentaho takes 3-5 minutes to fully start up
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
# Verifies that Kubernetes Services exist for network access to pods
# Services provide stable DNS names and load balancing for pods
echo -e "\n${YELLOW}[3/6] Checking Services${NC}"
check_component "PostgreSQL service" \
    "kubectl get svc postgres -n ${NAMESPACE}"
check_component "Pentaho Server service" \
    "kubectl get svc pentaho-server -n ${NAMESPACE}"

# -----------------------------------------------------------------------------
# PVC Checks
# -----------------------------------------------------------------------------
# Validates that all PersistentVolumeClaims are in "Bound" status
# PVCs must be bound to PersistentVolumes for data persistence to work
#
# Three PVCs are required:
#   - postgres-data-pvc: PostgreSQL database files (10Gi)
#   - pentaho-data-pvc: Pentaho Server data directory (10Gi)
#   - pentaho-solutions-pvc: Pentaho solutions repository (5Gi)
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
# Verifies that ConfigMaps exist for application configuration
#
# Two ConfigMaps are required:
#   - pentaho-config: Pentaho Server environment variables
#   - postgres-init: SQL scripts for database initialization
echo -e "\n${YELLOW}[5/6] Checking ConfigMaps${NC}"
check_component "pentaho-config ConfigMap" \
    "kubectl get configmap pentaho-config -n ${NAMESPACE}"
check_component "postgres-init ConfigMap" \
    "kubectl get configmap postgres-init -n ${NAMESPACE}"

# -----------------------------------------------------------------------------
# Ingress Check
# -----------------------------------------------------------------------------
# Verifies that the Traefik Ingress resource exists
# The Ingress routes external HTTP traffic to the Pentaho Server service
echo -e "\n${YELLOW}[6/6] Checking Ingress${NC}"
check_component "pentaho-ingress" \
    "kubectl get ingress pentaho-ingress -n ${NAMESPACE}"

# -----------------------------------------------------------------------------
# Database Connectivity Test
# -----------------------------------------------------------------------------
# Tests actual database connectivity by running SQL queries
# This verifies that databases were initialized correctly and are accessible
#
# Tests all three Pentaho repository databases:
#   - jackrabbit: JCR content repository
#   - quartz: Job scheduler database
#   - hibernate: Pentaho configuration repository
echo -e "\n${YELLOW}Testing Database Connectivity${NC}"

POSTGRES_POD=$(kubectl get pod -l app=postgres -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "${POSTGRES_POD}" ]; then
    # Test database connections by running a simple SELECT query
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
# Displays overall validation results
# Exit code equals the number of failed checks (0 = success)
echo -e "\n${BLUE}=============================================="
echo "  Validation Summary"
echo "==============================================${NC}"

if [ ${ERRORS} -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo "Your Pentaho K3s deployment is healthy and ready to use."
else
    echo -e "${RED}${ERRORS} check(s) failed${NC}"
    echo "Please review the errors above and take corrective action."
    echo ""
    echo "Common troubleshooting steps:"
    echo "  - Check pod logs: kubectl logs -n pentaho <pod-name>"
    echo "  - Describe pod: kubectl describe pod -n pentaho <pod-name>"
    echo "  - Check events: kubectl get events -n pentaho --sort-by='.lastTimestamp'"
fi

# -----------------------------------------------------------------------------
# Resource Overview
# -----------------------------------------------------------------------------
# Displays all Kubernetes resources in the pentaho namespace
# Includes: pods, services, deployments, replicasets, and ingress
echo ""
echo -e "${YELLOW}Resource Overview:${NC}"
kubectl get all -n ${NAMESPACE}

# -----------------------------------------------------------------------------
# Access Information
# -----------------------------------------------------------------------------
# Provides connection details for accessing Pentaho Server
# Includes both ingress and port-forward methods
echo ""
echo -e "${YELLOW}Access URLs:${NC}"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Node IP: ${NODE_IP}"
echo ""
echo "Method 1: Via Ingress (recommended)"
echo "  Add to /etc/hosts: ${NODE_IP} pentaho.local"
echo "  Then access: http://pentaho.local/pentaho"
echo ""
echo "Method 2: Via Port-Forward (for testing/development)"
echo "  Run: kubectl port-forward svc/pentaho-server 8080:8080 -n pentaho"
echo "  Then access: http://localhost:8080/pentaho"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: password"

# Exit with error count (0 = success, non-zero = failures)
exit ${ERRORS}
