#!/bin/bash
# =============================================================================
# Pentaho K3s Complete Deployment Script
# =============================================================================
#
# This unified script handles the complete deployment process for Pentaho
# Server on K3s, including:
#   - Docker image import into K3s container runtime
#   - Kubernetes resource creation (namespace, secrets, configmaps, storage)
#   - PostgreSQL database deployment
#   - Pentaho Server deployment
#   - Ingress configuration
#   - Health checks and status reporting
#
# Usage:
#   ./deploy.sh                    # Fresh deployment with image import
#   ./deploy.sh --skip-import      # Deploy without importing image
#   ./deploy.sh --update-only      # Only update existing deployment
#   ./deploy.sh --clean            # Remove old images before deploying
#
# Prerequisites:
#   - K3s installed and running
#   - Docker image built: pentaho/pentaho-server:11.0.0.0-237
#   - kubectl configured to access K3s cluster
#   - sudo access for K3s containerd operations
#
# Notes:
#   - First-time deployment takes 5-10 minutes
#   - Pentaho Server startup takes 3-5 minutes after pod creation
#   - Default credentials: admin/password (change for production!)
#
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# Configuration Variables
# =============================================================================

# Script directory (location of this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Manifests directory containing all Kubernetes YAML files
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"

# Docker image details
IMAGE_NAME="pentaho/pentaho-server"
IMAGE_TAG="11.0.0.0-237"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# Kubernetes namespace for Pentaho deployment
K8S_NAMESPACE="pentaho"

# =============================================================================
# Color Codes for Terminal Output
# =============================================================================
RED='\033[0;31m'      # Error messages
GREEN='\033[0;32m'    # Success messages
YELLOW='\033[1;33m'   # Warning/info messages
BLUE='\033[0;34m'     # Section headers
NC='\033[0m'          # No Color (reset)

# =============================================================================
# Command-Line Argument Processing
# =============================================================================

SKIP_IMAGE_IMPORT=false
UPDATE_ONLY=false
CLEAN_OLD_IMAGES=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-import)
            SKIP_IMAGE_IMPORT=true
            shift
            ;;
        --update-only)
            UPDATE_ONLY=true
            shift
            ;;
        --clean)
            CLEAN_OLD_IMAGES=true
            shift
            ;;
        --help|-h)
            echo "Pentaho K3s Deployment Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-import    Skip Docker image import (use if image already in K3s)"
            echo "  --update-only    Only update existing deployment (don't create resources)"
            echo "  --clean          Remove old Pentaho images from K3s before deploying"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                     # Fresh deployment (default)"
            echo "  $0 --skip-import       # Deploy without importing image"
            echo "  $0 --update-only       # Just restart pods with new image"
            echo "  $0 --clean             # Clean old images first"
            exit 0
            ;;
        *)
            echo -e "${RED}ERROR: Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# =============================================================================
# Helper Functions
# =============================================================================

# Print a section header
print_header() {
    echo ""
    echo -e "${BLUE}=============================================="
    echo -e "  $1"
    echo -e "==============================================${NC}"
    echo ""
}

# Print a step message
print_step() {
    echo -e "${YELLOW}$1${NC}"
}

# Print a success message
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print an error message and exit
print_error() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

# Print an informational message
print_info() {
    echo -e "${YELLOW}$1${NC}"
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

print_header "Pentaho K3s Deployment"

print_step "Running pre-flight checks..."

# Check if Docker is available (needed for image export)
if ! command -v docker &> /dev/null; then
    print_error "docker not found. Docker is required to export images."
fi
print_success "Docker found: $(docker --version | head -1)"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found. Is K3s installed? Install with: curl -sfL https://get.k3s.io | sh -"
fi
print_success "kubectl found"

# Check if K3s containerd tool is available (for image import)
if ! command -v k3s &> /dev/null; then
    print_error "k3s command not found. Is K3s installed?"
fi
print_success "k3s found"

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Make sure K3s is running."
fi
print_success "Kubernetes cluster is accessible"

# Check if Docker image exists locally
if ! docker image inspect "${FULL_IMAGE}" &> /dev/null; then
    print_error "Docker image '${FULL_IMAGE}' not found. Build it first with: cd docker-build && ./build.sh"
fi
print_success "Docker image '${FULL_IMAGE}' found"

# Check if secrets file exists, create from template if not
if [ ! -f "${MANIFESTS_DIR}/secrets/secrets.yaml" ]; then
    print_info "Creating secrets file from template..."
    cp "${MANIFESTS_DIR}/secrets/secrets.yaml.template" "${MANIFESTS_DIR}/secrets/secrets.yaml"
    print_info "NOTE: Using default passwords. Change them for production!"
fi
print_success "Secrets file exists"

echo ""

# =============================================================================
# Image Import to K3s
# =============================================================================

if [ "$UPDATE_ONLY" = false ]; then
    if [ "$SKIP_IMAGE_IMPORT" = false ]; then
        print_header "Docker Image Import"

        # Clean old images if requested
        if [ "$CLEAN_OLD_IMAGES" = true ]; then
            print_step "Cleaning up old Pentaho images from K3s..."

            # List old images and remove them
            # Note: This requires sudo as K3s containerd runs with elevated privileges
            if sudo k3s ctr images ls -q 2>/dev/null | grep -q "${IMAGE_NAME}"; then
                sudo k3s ctr images ls -q | grep "${IMAGE_NAME}" | while read img; do
                    echo "  Deleting: $img"
                    sudo k3s ctr images rm "$img" 2>/dev/null || true
                done
                print_success "Old images removed"
            else
                print_info "No old images found to clean"
            fi
            echo ""
        fi

        print_step "Importing Pentaho image to K3s container runtime..."
        print_info "This will transfer ~1.3GB and may take 30-60 seconds..."

        # Export Docker image and pipe directly to K3s containerd import
        # This is more efficient than saving to a tar file first
        # The 'sudo' is required because K3s containerd socket is owned by root
        if docker save "${FULL_IMAGE}" | sudo k3s ctr images import - 2>&1 | grep -v "unpacking"; then
            print_success "Image imported successfully"
        else
            print_error "Failed to import image to K3s"
        fi

        # Verify the image is now available in K3s
        print_step "Verifying image in K3s containerd..."
        if sudo k3s ctr images ls | grep -q "${IMAGE_NAME}"; then
            sudo k3s ctr images ls | grep "${IMAGE_NAME}"
            print_success "Image verified in K3s"
        else
            print_error "Image not found in K3s after import"
        fi

        echo ""
    else
        print_info "Skipping image import (--skip-import flag used)"
        echo ""
    fi
fi

# =============================================================================
# Kubernetes Resource Deployment
# =============================================================================

if [ "$UPDATE_ONLY" = false ]; then
    print_header "Deploying Kubernetes Resources"

    # Step 1: Create namespace
    # The namespace isolates all Pentaho resources in the cluster
    print_step "[1/7] Creating namespace '${K8S_NAMESPACE}'..."
    kubectl apply -f "${MANIFESTS_DIR}/namespace.yaml"
    print_success "Namespace created"
    echo ""

    # Step 2: Create secrets
    # Secrets contain sensitive data like database passwords
    # They are mounted as environment variables in pods
    print_step "[2/7] Creating secrets..."
    kubectl apply -f "${MANIFESTS_DIR}/secrets/secrets.yaml"
    print_success "Secrets created"
    echo ""

    # Step 3: Create ConfigMaps
    # ConfigMaps contain non-sensitive configuration data
    # These include JVM settings, database URLs, timezone, etc.
    print_step "[3/7] Creating ConfigMaps..."
    kubectl apply -f "${MANIFESTS_DIR}/configmaps/"
    print_success "ConfigMaps created"
    echo ""

    # Step 4: Create PersistentVolumeClaims
    # PVCs request storage for stateful data
    # Pentaho uses these for data, solutions, and PostgreSQL data
    print_step "[4/7] Creating PersistentVolumeClaims..."
    kubectl apply -f "${MANIFESTS_DIR}/storage/"
    print_success "PVCs created"
    echo ""

    # Step 5: Deploy PostgreSQL
    # PostgreSQL stores Pentaho's repository data (Hibernate, JackRabbit, Quartz)
    print_step "[5/7] Deploying PostgreSQL database..."
    kubectl apply -f "${MANIFESTS_DIR}/postgres/"
    print_success "PostgreSQL deployment created"

    # Wait for PostgreSQL to be ready before proceeding
    # This prevents Pentaho from failing to connect on startup
    print_step "    Waiting for PostgreSQL to be ready (timeout: 180s)..."
    if kubectl wait --for=condition=ready pod -l app=postgres -n "${K8S_NAMESPACE}" --timeout=180s 2>&1; then
        print_success "PostgreSQL is ready"
    else
        print_error "PostgreSQL failed to start within 180 seconds"
    fi
    echo ""

    # Step 6: Deploy Pentaho Server
    # This creates the main Pentaho deployment with the imported container image
    print_step "[6/7] Deploying Pentaho Server..."
    kubectl apply -f "${MANIFESTS_DIR}/pentaho/"
    print_success "Pentaho deployment created"
    echo ""

    # Step 7: Create Ingress
    # Ingress provides external HTTP/HTTPS access to Pentaho
    # Traefik (K3s default) handles the ingress routing
    print_step "[7/7] Creating Ingress..."
    kubectl apply -f "${MANIFESTS_DIR}/ingress/"
    print_success "Ingress created"
    echo ""

else
    # Update-only mode: Just restart the Pentaho pods to pick up new image
    print_header "Updating Pentaho Deployment"

    print_step "Deleting existing Pentaho pods..."
    print_info "Kubernetes will automatically recreate them with the new image"

    # Delete pods matching the pentaho-server label
    # The deployment controller will immediately recreate them
    # imagePullPolicy: IfNotPresent ensures new image is used
    if kubectl delete pod -n "${K8S_NAMESPACE}" -l app=pentaho-server 2>/dev/null; then
        print_success "Pods deleted, new pods will be created automatically"
    else
        print_info "No pods found to delete (deployment may not exist yet)"
    fi

    echo ""
fi

# =============================================================================
# Post-Deployment Status and Information
# =============================================================================

print_header "Deployment Complete!"

# Display current resource status
print_step "Resource Status:"
kubectl get all -n "${K8S_NAMESPACE}"

echo ""
print_step "PersistentVolumeClaims:"
kubectl get pvc -n "${K8S_NAMESPACE}"

echo ""
print_step "Ingress:"
kubectl get ingress -n "${K8S_NAMESPACE}"

# Get node IP for ingress access instructions
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
print_header "Access Information"

echo "Pentaho Server is starting up..."
print_info "Startup time: 3-5 minutes (first start may take longer)"
echo ""

echo "Access Methods:"
echo ""
echo "1. Via Ingress (add to /etc/hosts: ${NODE_IP} pentaho.local):"
echo -e "   ${GREEN}http://pentaho.local/pentaho${NC}"
echo ""
echo "2. Via port-forward (for local testing):"
echo "   kubectl port-forward svc/pentaho-server 8080:8080 -n ${K8S_NAMESPACE}"
echo -e "   ${GREEN}http://localhost:8080/pentaho${NC}"
echo ""

print_info "Default Credentials:"
echo "   Username: admin"
echo "   Password: password"
echo -e "   ${YELLOW}⚠ Change these for production deployments!${NC}"
echo ""

print_header "Monitoring Commands"

echo "Monitor pod startup:"
echo -e "   ${GREEN}kubectl get pods -n ${K8S_NAMESPACE} -w${NC}"
echo ""

echo "Watch Pentaho logs:"
echo -e "   ${GREEN}kubectl logs -f deployment/pentaho-server -n ${K8S_NAMESPACE}${NC}"
echo ""

echo "Check all resources:"
echo -e "   ${GREEN}kubectl get all -n ${K8S_NAMESPACE}${NC}"
echo ""

echo "Describe pod (for troubleshooting):"
echo -e "   ${GREEN}kubectl describe pod -n ${K8S_NAMESPACE} -l app=pentaho-server${NC}"
echo ""

print_header "What Happens Next"

echo "1. Pentaho pod will initialize (1-2 minutes)"
echo "2. Tomcat will start and load Pentaho web apps (2-3 minutes)"
echo "3. Pentaho will initialize its repository in PostgreSQL (1-2 minutes on first start)"
echo "4. Login page will become available at the URLs above"
echo ""

print_info "Total time to availability: 3-5 minutes for fresh deployment"
print_info "Subsequent restarts: 2-3 minutes"
echo ""

print_success "Deployment script completed successfully!"
echo ""
