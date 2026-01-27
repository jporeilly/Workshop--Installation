#!/bin/bash
# =============================================================================
# Pentaho Docker Image Builder (with .env configuration)
# =============================================================================
# This script builds a Pentaho Docker image using configuration from .env file
#
# Usage:
#   ./build.sh [options]
#
# Options:
#   --env-file FILE    Use specific .env file (default: .env)
#   --dry-run          Show what would be built without building
#   --help             Show this help message
#
# Prerequisites:
#   1. Docker installed and running
#   2. Pentaho package in stagedArtifacts/
#   3. .env file configured (copy from .env.example)
#
# =============================================================================

set -e  # Exit on error

# -----------------------------------------------------------------------------
# Color Output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

log_info() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo
}

# -----------------------------------------------------------------------------
# Parse Command Line Arguments
# -----------------------------------------------------------------------------

ENV_FILE=".env"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --env-file FILE    Use specific .env file (default: .env)"
            echo "  --dry-run          Show what would be built without building"
            echo "  --help             Show this help message"
            echo ""
            echo "Environment variables are loaded from .env file."
            echo "Copy .env.example to .env and customize before running."
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Load Environment Configuration
# -----------------------------------------------------------------------------

print_header "Pentaho Docker Image Builder"

if [ ! -f "$ENV_FILE" ]; then
    log_error "Configuration file not found: $ENV_FILE"
    echo ""
    echo "Please create .env file from template:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    echo ""
    exit 1
fi

log_info "Loading configuration from: $ENV_FILE"

# Source the .env file
set -a  # Automatically export all variables
source "$ENV_FILE"
set +a

# -----------------------------------------------------------------------------
# Set Defaults for Optional Variables
# -----------------------------------------------------------------------------

PENTAHO_VERSION=${PENTAHO_VERSION:-11.0.0.0-237}
EDITION=${EDITION:-ee}
INCLUDE_DEMO=${INCLUDE_DEMO:-0}
IMAGE_TAG=${IMAGE_TAG:-pentaho/pentaho-server:${PENTAHO_VERSION}}
INSTALLATION_PATH=${INSTALLATION_PATH:-/opt/pentaho}
UNPACK_BUILD_IMAGE=${UNPACK_BUILD_IMAGE:-debian:trixie-slim}
PACK_BUILD_IMAGE=${PACK_BUILD_IMAGE:-debian:trixie-slim}
PUSH_TO_REGISTRY=${PUSH_TO_REGISTRY:-false}
LOAD_INTO_K3S=${LOAD_INTO_K3S:-false}
USE_BUILDKIT=${USE_BUILDKIT:-true}
NO_CACHE=${NO_CACHE:-false}
VERBOSE=${VERBOSE:-false}
RUN_TESTS=${RUN_TESTS:-true}
DEBUG=${DEBUG:-false}
BUILD_PLATFORM=${BUILD_PLATFORM:-linux/amd64}

# -----------------------------------------------------------------------------
# Display Configuration
# -----------------------------------------------------------------------------

echo "Configuration:"
echo "  Pentaho Version:  $PENTAHO_VERSION"
echo "  Edition:          $EDITION"
echo "  Include Demo:     $([ "$INCLUDE_DEMO" = "1" ] && echo 'Yes' || echo 'No')"
echo "  Image Tag:        $IMAGE_TAG"
echo "  Build Platform:   $BUILD_PLATFORM"
echo ""
echo "Runtime Settings:"
echo "  JVM Memory:       ${PENTAHO_MIN_MEMORY:-2048m} - ${PENTAHO_MAX_MEMORY:-4096m}"
echo "  Timezone:         ${TZ:-America/New_York}"
echo "  Database:         ${DB_TYPE:-postgres}"
if [ -n "$LICENSE_URL" ]; then
    echo "  License URL:      $LICENSE_URL"
else
    echo "  License URL:      (not set - will run without EE license)"
fi
echo ""
echo "Actions:"
echo "  Push to Registry: $PUSH_TO_REGISTRY"
echo "  Load into K3s:    $LOAD_INTO_K3S"
echo "  Run Tests:        $RUN_TESTS"
echo ""

# -----------------------------------------------------------------------------
# Dry Run Mode
# -----------------------------------------------------------------------------

if [ "$DRY_RUN" = true ]; then
    print_header "Dry Run Mode"
    echo "Would execute the following build command:"
    echo ""
    echo "docker build \\"
    echo "  --build-arg PENTAHO_VERSION=$PENTAHO_VERSION \\"
    echo "  --build-arg PENTAHO_INSTALLER_NAME=pentaho-server-$EDITION \\"
    echo "  --build-arg IS_DEMO=$INCLUDE_DEMO \\"
    echo "  --build-arg INSTALLATION_PATH=$INSTALLATION_PATH \\"
    echo "  --build-arg UNPACK_BUILD_IMAGE=$UNPACK_BUILD_IMAGE \\"
    echo "  --build-arg PACK_BUILD_IMAGE=$PACK_BUILD_IMAGE \\"
    echo "  --platform $BUILD_PLATFORM \\"
    echo "  -t $IMAGE_TAG \\"
    echo "  ."
    echo ""
    exit 0
fi

# -----------------------------------------------------------------------------
# Validate Prerequisites
# -----------------------------------------------------------------------------

log_info "Validating prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed or not in PATH"
    exit 1
fi

DOCKER_VERSION=$(docker --version)
log_success "Docker found: $DOCKER_VERSION"

# Check Pentaho package
PENTAHO_PACKAGE="stagedArtifacts/pentaho-server-${EDITION}-${PENTAHO_VERSION}.zip"
if [ ! -f "$PENTAHO_PACKAGE" ]; then
    log_error "Pentaho package not found: $PENTAHO_PACKAGE"
    echo ""
    echo "Please place your Pentaho package in:"
    echo "  $PENTAHO_PACKAGE"
    echo ""
    exit 1
fi

PACKAGE_SIZE=$(du -h "$PENTAHO_PACKAGE" | cut -f1)
log_success "Found Pentaho package: $PENTAHO_PACKAGE ($PACKAGE_SIZE)"

# Check for plugins
log_info "Checking for optional plugins..."
PLUGIN_COUNT=0
for plugin in paz pir pdd; do
    PLUGIN_FILE="stagedArtifacts/${plugin}-plugin-${EDITION}-${PENTAHO_VERSION}.zip"
    if [ -f "$PLUGIN_FILE" ]; then
        log_success "Found plugin: $plugin"
        PLUGIN_COUNT=$((PLUGIN_COUNT + 1))
    fi
done

if [ $PLUGIN_COUNT -eq 0 ]; then
    log_info "No plugins found (this is optional)"
else
    log_success "Found $PLUGIN_COUNT plugin(s)"
fi

echo ""

# -----------------------------------------------------------------------------
# Build Docker Image
# -----------------------------------------------------------------------------

print_header "Building Docker Image"

# Prepare build arguments
BUILD_ARGS=(
    "--build-arg" "PENTAHO_VERSION=$PENTAHO_VERSION"
    "--build-arg" "PENTAHO_INSTALLER_NAME=pentaho-server-$EDITION"
    "--build-arg" "IS_DEMO=$INCLUDE_DEMO"
    "--build-arg" "INSTALLATION_PATH=$INSTALLATION_PATH"
    "--build-arg" "UNPACK_BUILD_IMAGE=$UNPACK_BUILD_IMAGE"
    "--build-arg" "PACK_BUILD_IMAGE=$PACK_BUILD_IMAGE"
)

# Add platform
BUILD_ARGS+=("--platform" "$BUILD_PLATFORM")

# Add image tag
BUILD_ARGS+=("-t" "$IMAGE_TAG")

# Add additional tags if specified
if [ -n "$IMAGE_TAG_LATEST" ]; then
    BUILD_ARGS+=("-t" "$IMAGE_TAG_LATEST")
fi
if [ -n "$IMAGE_TAG_MAJOR" ]; then
    BUILD_ARGS+=("-t" "$IMAGE_TAG_MAJOR")
fi

# Add labels for metadata
BUILD_ARGS+=(
    "--label" "version=$PENTAHO_VERSION"
    "--label" "edition=$EDITION"
    "--label" "build-date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
)

# No cache option
if [ "$NO_CACHE" = true ]; then
    BUILD_ARGS+=("--no-cache")
fi

# Progress output
if [ "$VERBOSE" = true ]; then
    BUILD_ARGS+=("--progress=plain")
fi

# Enable BuildKit if requested
if [ "$USE_BUILDKIT" = true ]; then
    export DOCKER_BUILDKIT=1
    log_info "BuildKit enabled"
fi

# Show build command in debug mode
if [ "$DEBUG" = true ]; then
    log_info "Build command:"
    echo "docker build ${BUILD_ARGS[*]} ."
    echo ""
fi

log_info "Starting build..."
START_TIME=$(date +%s)

# Execute build
if docker build "${BUILD_ARGS[@]}" .; then
    END_TIME=$(date +%s)
    BUILD_DURATION=$((END_TIME - START_TIME))

    log_success "Build completed in ${BUILD_DURATION}s"
    echo ""
else
    log_error "Build failed!"
    exit 1
fi

# -----------------------------------------------------------------------------
# Display Image Information
# -----------------------------------------------------------------------------

print_header "Image Information"

IMAGE_SIZE=$(docker images "$IMAGE_TAG" --format "{{.Size}}")
IMAGE_ID=$(docker images "$IMAGE_TAG" --format "{{.ID}}")

echo "  Tag:  $IMAGE_TAG"
echo "  Size: $IMAGE_SIZE"
echo "  ID:   $IMAGE_ID"
echo ""

# Show all tags
echo "All tags for this image:"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep -E "$(echo $IMAGE_TAG | cut -d: -f1)" || true
echo ""

# -----------------------------------------------------------------------------
# Run Tests
# -----------------------------------------------------------------------------

if [ "$RUN_TESTS" = true ]; then
    print_header "Testing Image"

    log_info "Running basic validation tests..."

    # Test 1: Check Java version
    log_info "Test 1: Checking Java version..."
    if docker run --rm "$IMAGE_TAG" java -version 2>&1 | head -5; then
        log_success "Java version check passed"
    else
        log_error "Java version check failed"
        exit 1
    fi
    echo ""

    # Test 2: Verify Pentaho files exist
    log_info "Test 2: Verifying Pentaho installation..."
    if docker run --rm "$IMAGE_TAG" ls -la /opt/pentaho/pentaho-server | head -10; then
        log_success "Pentaho files verified"
    else
        log_error "Pentaho files verification failed"
        exit 1
    fi
    echo ""

    log_success "All tests passed!"
    echo ""
fi

# -----------------------------------------------------------------------------
# Push to Registry
# -----------------------------------------------------------------------------

if [ "$PUSH_TO_REGISTRY" = true ]; then
    print_header "Pushing to Registry"

    # Login to registry if credentials provided
    if [ -n "$REGISTRY_URL" ] && [ -n "$REGISTRY_USERNAME" ] && [ -n "$REGISTRY_PASSWORD" ]; then
        log_info "Logging in to registry: $REGISTRY_URL"
        echo "$REGISTRY_PASSWORD" | docker login "$REGISTRY_URL" -u "$REGISTRY_USERNAME" --password-stdin
    fi

    log_info "Pushing image: $IMAGE_TAG"
    if docker push "$IMAGE_TAG"; then
        log_success "Image pushed successfully"
    else
        log_error "Failed to push image"
        exit 1
    fi

    # Push additional tags
    if [ -n "$IMAGE_TAG_LATEST" ]; then
        log_info "Pushing tag: $IMAGE_TAG_LATEST"
        docker push "$IMAGE_TAG_LATEST"
    fi
    if [ -n "$IMAGE_TAG_MAJOR" ]; then
        log_info "Pushing tag: $IMAGE_TAG_MAJOR"
        docker push "$IMAGE_TAG_MAJOR"
    fi

    echo ""
fi

# -----------------------------------------------------------------------------
# Load into K3s
# -----------------------------------------------------------------------------

if [ "$LOAD_INTO_K3S" = true ]; then
    print_header "Loading into K3s"

    log_info "Importing image into K3s..."
    if docker save "$IMAGE_TAG" | sudo k3s ctr images import -; then
        log_success "Image imported into K3s successfully"

        # Verify import
        log_info "Verifying image in K3s..."
        sudo k3s ctr images ls | grep pentaho || log_warning "Image not found in K3s image list"

        # Update K3s deployment if specified
        if [ -n "$K3S_DEPLOYMENT" ] && [ -n "$K3S_NAMESPACE" ]; then
            # Check if namespace exists first
            if kubectl get namespace "$K3S_NAMESPACE" > /dev/null 2>&1; then
                log_info "Updating K3s deployment..."
                if kubectl set image "deployment/$K3S_DEPLOYMENT" \
                    pentaho-server="$IMAGE_TAG" \
                    -n "$K3S_NAMESPACE"; then
                    log_success "Deployment updated"

                    # Watch rollout status
                    log_info "Watching rollout status..."
                    kubectl rollout status "deployment/$K3S_DEPLOYMENT" -n "$K3S_NAMESPACE" --timeout=5m
                else
                    log_warning "Deployment not found (will be created when you run: kubectl apply -f ../manifests/)"
                fi
            else
                log_info "Namespace '$K3S_NAMESPACE' not found - skipping deployment update"
                log_info "Deploy with: kubectl apply -f ../manifests/"
            fi
        fi
    else
        log_error "Failed to import image into K3s"
        exit 1
    fi

    echo ""
fi

# -----------------------------------------------------------------------------
# Send Notification
# -----------------------------------------------------------------------------

if [ "$SEND_NOTIFICATION" = true ] && [ -n "$NOTIFICATION_WEBHOOK_URL" ]; then
    log_info "Sending build notification..."

    NOTIFICATION_PAYLOAD=$(cat <<EOF
{
    "text": "Pentaho Docker Build Completed",
    "blocks": [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Pentaho Docker Build Completed* :white_check_mark:"
            }
        },
        {
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": "*Version:*\n$PENTAHO_VERSION"},
                {"type": "mrkdwn", "text": "*Edition:*\n$EDITION"},
                {"type": "mrkdwn", "text": "*Image Tag:*\n\`$IMAGE_TAG\`"},
                {"type": "mrkdwn", "text": "*Size:*\n$IMAGE_SIZE"}
            ]
        }
    ]
}
EOF
)

    curl -X POST -H 'Content-type: application/json' \
        --data "$NOTIFICATION_PAYLOAD" \
        "$NOTIFICATION_WEBHOOK_URL" > /dev/null 2>&1

    log_success "Notification sent"
fi

# -----------------------------------------------------------------------------
# Summary and Next Steps
# -----------------------------------------------------------------------------

print_header "Build Complete!"

echo "Image built successfully: $IMAGE_TAG"
echo ""

if [ "$LOAD_INTO_K3S" = true ]; then
    echo "✅ Image loaded into K3s"
else
    echo "Next steps:"
    echo ""
    echo "1. Load image into K3s:"
    echo "   docker save $IMAGE_TAG | sudo k3s ctr images import -"
    echo ""
fi

if [ "$PUSH_TO_REGISTRY" = false ]; then
    echo "2. Or push to registry:"
    echo "   docker push $IMAGE_TAG"
    echo ""
fi

echo "3. Deploy to K3s:"
echo "   kubectl set image deployment/pentaho-server \\"
echo "       pentaho-server=$IMAGE_TAG -n pentaho"
echo ""
echo "4. Monitor deployment:"
echo "   kubectl get pods -n pentaho -w"
echo ""

if [ -n "$LICENSE_URL" ]; then
    echo "License URL configured: $LICENSE_URL"
    echo "License will be installed automatically on first container start."
    echo ""
fi

log_success "All done!"
