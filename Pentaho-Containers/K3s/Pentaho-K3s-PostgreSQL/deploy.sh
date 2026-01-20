#!/bin/bash
# =============================================================================
# Pentaho K3s Deployment Script
# =============================================================================
# Deploys Pentaho Server with PostgreSQL on K3s
#
# Usage: ./deploy.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"

echo -e "${BLUE}"
echo "=============================================="
echo "  Pentaho K3s Deployment"
echo "=============================================="
echo -e "${NC}"

# -----------------------------------------------------------------------------
# Pre-flight Checks
# -----------------------------------------------------------------------------
echo -e "${YELLOW}Running pre-flight checks...${NC}"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}ERROR: kubectl not found. Is K3s installed?${NC}"
    echo "Install K3s with: curl -sfL https://get.k3s.io | sh -"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}ERROR: Cannot connect to Kubernetes cluster${NC}"
    echo "Make sure K3s is running and KUBECONFIG is set correctly"
    echo "Try: export KUBECONFIG=~/.kube/config"
    exit 1
fi

echo -e "${GREEN}✓ kubectl configured and cluster accessible${NC}"

# Check if secrets file exists
if [ ! -f "${MANIFESTS_DIR}/secrets/secrets.yaml" ]; then
    echo -e "${YELLOW}Creating secrets file from template...${NC}"
    cp "${MANIFESTS_DIR}/secrets/secrets.yaml.template" "${MANIFESTS_DIR}/secrets/secrets.yaml"
    echo -e "${YELLOW}NOTE: Using default passwords. Change them for production!${NC}"
fi

# -----------------------------------------------------------------------------
# Deploy Resources
# -----------------------------------------------------------------------------

echo ""
echo -e "${BLUE}Deploying Pentaho to K3s...${NC}"
echo ""

# Step 1: Create namespace
echo -e "${YELLOW}[1/7] Creating namespace...${NC}"
kubectl apply -f "${MANIFESTS_DIR}/namespace.yaml"
echo -e "${GREEN}✓ Namespace created${NC}"

# Step 2: Create secrets
echo -e "${YELLOW}[2/7] Creating secrets...${NC}"
kubectl apply -f "${MANIFESTS_DIR}/secrets/secrets.yaml"
echo -e "${GREEN}✓ Secrets created${NC}"

# Step 3: Create ConfigMaps
echo -e "${YELLOW}[3/7] Creating ConfigMaps...${NC}"
kubectl apply -f "${MANIFESTS_DIR}/configmaps/"
echo -e "${GREEN}✓ ConfigMaps created${NC}"

# Step 4: Create PersistentVolumeClaims
echo -e "${YELLOW}[4/7] Creating PersistentVolumeClaims...${NC}"
kubectl apply -f "${MANIFESTS_DIR}/storage/"
echo -e "${GREEN}✓ PVCs created${NC}"

# Step 5: Deploy PostgreSQL
echo -e "${YELLOW}[5/7] Deploying PostgreSQL...${NC}"
kubectl apply -f "${MANIFESTS_DIR}/postgres/"
echo -e "${GREEN}✓ PostgreSQL deployment created${NC}"

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}    Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=postgres -n pentaho --timeout=180s
echo -e "${GREEN}✓ PostgreSQL is ready${NC}"

# Step 6: Deploy Pentaho Server
echo -e "${YELLOW}[6/7] Deploying Pentaho Server...${NC}"
kubectl apply -f "${MANIFESTS_DIR}/pentaho/"
echo -e "${GREEN}✓ Pentaho deployment created${NC}"

# Step 7: Create Ingress
echo -e "${YELLOW}[7/7] Creating Ingress...${NC}"
kubectl apply -f "${MANIFESTS_DIR}/ingress/"
echo -e "${GREEN}✓ Ingress created${NC}"

# -----------------------------------------------------------------------------
# Post-Deployment Information
# -----------------------------------------------------------------------------

echo ""
echo -e "${BLUE}=============================================="
echo "  Deployment Complete!"
echo "==============================================${NC}"
echo ""

# Show resource status
echo -e "${YELLOW}Resource Status:${NC}"
kubectl get all -n pentaho

echo ""
echo -e "${YELLOW}PersistentVolumeClaims:${NC}"
kubectl get pvc -n pentaho

echo ""
echo -e "${YELLOW}Ingress:${NC}"
kubectl get ingress -n pentaho

# Get node IP for access
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo -e "${GREEN}=============================================="
echo "  Access Information"
echo "==============================================${NC}"
echo ""
echo "Pentaho Server is starting up (this may take 3-5 minutes)..."
echo ""
echo "Access methods:"
echo ""
echo "1. Via Ingress (add to /etc/hosts: ${NODE_IP} pentaho.local):"
echo "   URL: http://pentaho.local/pentaho"
echo ""
echo "2. Via port-forward (for testing):"
echo "   kubectl port-forward svc/pentaho-server 8080:8080 -n pentaho"
echo "   URL: http://localhost:8080/pentaho"
echo ""
echo "Default credentials:"
echo "   Username: admin"
echo "   Password: password"
echo ""
echo -e "${YELLOW}Monitor startup:${NC}"
echo "   kubectl logs -f deployment/pentaho-server -n pentaho"
echo ""
echo -e "${YELLOW}Check pod status:${NC}"
echo "   kubectl get pods -n pentaho -w"
echo ""
