#!/bin/bash
# =============================================================================
# Pentaho K3s Cleanup Script
# =============================================================================
# Removes all Pentaho resources from K3s
#
# Usage: ./destroy.sh [--keep-data]
#
# Options:
#   --keep-data    Keep PersistentVolumeClaims (preserves data)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

KEEP_DATA=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./destroy.sh [--keep-data]"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=============================================="
echo -e "  Pentaho K3s Cleanup"
echo -e "==============================================${NC}"

# Check if namespace exists
if ! kubectl get namespace pentaho &> /dev/null; then
    echo -e "${YELLOW}Namespace 'pentaho' does not exist. Nothing to clean up.${NC}"
    exit 0
fi

# Confirmation
echo -e "${RED}WARNING: This will delete all Pentaho resources!${NC}"
if [ "$KEEP_DATA" = true ]; then
    echo -e "${YELLOW}PersistentVolumeClaims will be preserved (--keep-data)${NC}"
else
    echo -e "${RED}PersistentVolumeClaims will be DELETED (data will be lost)${NC}"
fi
echo ""
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Deleting Pentaho resources...${NC}"

# Delete deployments first
echo -e "${YELLOW}Deleting deployments...${NC}"
kubectl delete deployment pentaho-server -n pentaho --ignore-not-found=true
kubectl delete deployment postgres -n pentaho --ignore-not-found=true

# Delete services
echo -e "${YELLOW}Deleting services...${NC}"
kubectl delete service pentaho-server -n pentaho --ignore-not-found=true
kubectl delete service postgres -n pentaho --ignore-not-found=true

# Delete ingress
echo -e "${YELLOW}Deleting ingress...${NC}"
kubectl delete ingress pentaho-ingress -n pentaho --ignore-not-found=true

# Delete configmaps
echo -e "${YELLOW}Deleting configmaps...${NC}"
kubectl delete configmap pentaho-config -n pentaho --ignore-not-found=true
kubectl delete configmap postgres-init-scripts -n pentaho --ignore-not-found=true

# Delete secrets
echo -e "${YELLOW}Deleting secrets...${NC}"
kubectl delete secret postgres-secrets -n pentaho --ignore-not-found=true
kubectl delete secret pentaho-db-secrets -n pentaho --ignore-not-found=true

# Delete PVCs if not keeping data
if [ "$KEEP_DATA" = false ]; then
    echo -e "${YELLOW}Deleting PersistentVolumeClaims...${NC}"
    kubectl delete pvc postgres-data-pvc -n pentaho --ignore-not-found=true
    kubectl delete pvc pentaho-data-pvc -n pentaho --ignore-not-found=true
    kubectl delete pvc pentaho-solutions-pvc -n pentaho --ignore-not-found=true
else
    echo -e "${YELLOW}Keeping PersistentVolumeClaims (--keep-data)${NC}"
fi

# Delete namespace
echo -e "${YELLOW}Deleting namespace...${NC}"
kubectl delete namespace pentaho --ignore-not-found=true

echo ""
echo -e "${GREEN}=============================================="
echo "  Cleanup Complete!"
echo "==============================================${NC}"
echo ""

if [ "$KEEP_DATA" = true ]; then
    echo "Note: PVCs were preserved. To fully clean up, run:"
    echo "  kubectl delete pvc -n pentaho --all"
fi
