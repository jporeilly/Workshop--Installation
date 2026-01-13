#!/bin/bash
# =============================================================================
# Pentaho Server 11 Docker Deployment Script (PostgreSQL)
# =============================================================================
#
# Automated deployment script for Pentaho Server 11 with PostgreSQL on Ubuntu 24.04
#
# Usage:
#   ./deploy.sh
#
# Prerequisites:
#   - Docker Engine 20.10+
#   - Docker Compose 2.0+
#   - pentaho-server-ee-11.0.0.0-237.zip in docker/stagedArtifacts/
#   - 10GB+ free disk space
#   - Ports 8090, 5432 available
#
# What this script does:
#   1. Pre-flight Checks
#      - Validates Docker and Docker Compose installation
#      - Verifies Pentaho package exists
#      - Creates .env from template if missing
#      - Checks disk space (10GB minimum)
#      - Verifies required ports are available
#
#   2. Build Phase
#      - Builds Pentaho Server Docker image
#      - Image based on debian:trixie-slim with OpenJDK 21
#
#   3. Startup Phase
#      - Starts PostgreSQL container and waits for health
#      - Starts Pentaho Server container
#
#   4. Verification
#      - Waits for Pentaho Server startup completion
#      - Displays access URLs and credentials
#
# Configuration:
#   Edit .env file to customize:
#   - PENTAHO_HTTP_PORT (default: 8090)
#   - POSTGRES_PASSWORD (default: password)
#   - PENTAHO_MIN_MEMORY / PENTAHO_MAX_MEMORY
#
# For more information, see:
#   - README.md - Quick start guide
#   - ARCHITECTURE.md - System design
#   - TROUBLESHOOTING.md - Problem solving
#
# =============================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo " Pentaho Server 11 Docker Deployment"
echo " (PostgreSQL Edition)"
echo "=========================================="
echo ""

# ============================================
# Pre-flight Checks
# ============================================

echo -e "${BLUE}→ Running pre-flight checks...${NC}"

# Check 1: Docker installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    echo "  Install Docker: https://docs.docker.com/engine/install/ubuntu/"
    exit 1
fi
echo -e "${GREEN}✓ Docker is installed${NC}"

# Check 2: Docker Compose installed
if ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose is not installed${NC}"
    echo "  Install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose is installed${NC}"

# Check 3: Docker daemon running
if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker daemon is not running${NC}"
    echo "  Start Docker: sudo systemctl start docker"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon is running${NC}"

# Check 4: Pentaho package exists
PENTAHO_PKG="docker/stagedArtifacts/pentaho-server-ee-11.0.0.0-237.zip"
if [ ! -f "$PENTAHO_PKG" ]; then
    echo -e "${RED}✗ Pentaho package not found: $PENTAHO_PKG${NC}"
    echo ""
    echo "  Please place the Pentaho package in: docker/stagedArtifacts/"
    echo "  Expected file: pentaho-server-ee-11.0.0.0-237.zip"
    exit 1
fi
echo -e "${GREEN}✓ Pentaho package found${NC}"

# Check 5: .env file exists or create from template
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠ .env file not found, creating from template...${NC}"
    if [ -f ".env.template" ]; then
        cp .env.template .env
        echo -e "${GREEN}✓ Created .env from template${NC}"
        echo -e "${YELLOW}  Please review .env file and adjust settings if needed${NC}"
    else
        echo -e "${RED}✗ .env.template not found${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ .env file exists${NC}"
fi

# Check 6: Disk space (require at least 10GB)
AVAILABLE_SPACE=$(df -BG "$SCRIPT_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 10 ]; then
    echo -e "${YELLOW}⚠ Warning: Low disk space (${AVAILABLE_SPACE}GB available, 10GB+ recommended)${NC}"
    read -p "Continue anyway? (yes/NO) " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
else
    echo -e "${GREEN}✓ Sufficient disk space (${AVAILABLE_SPACE}GB available)${NC}"
fi

# Check 7: Ports availability
echo -e "${BLUE}→ Checking port availability...${NC}"
source .env

check_port() {
    local port=$1
    local name=$2
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${YELLOW}⚠ Warning: Port $port ($name) is already in use${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Port $port ($name) is available${NC}"
        return 0
    fi
}

PORTS_OK=true
check_port "${PENTAHO_HTTP_PORT:-8090}" "Pentaho HTTP" || PORTS_OK=false
check_port "${POSTGRES_PORT:-5432}" "PostgreSQL" || PORTS_OK=false

if [ "$PORTS_OK" = false ]; then
    echo -e "${YELLOW}Some ports are in use. Continue anyway?${NC}"
    read -p "(yes/NO) " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
fi

echo ""
echo "=========================================="
echo " Starting Deployment"
echo "=========================================="
echo ""

# ============================================
# Build and Start Services
# ============================================

# Build Pentaho Server image
echo -e "${BLUE}→ Building Pentaho Server Docker image...${NC}"
echo "  This may take 5-10 minutes..."
if docker compose build --no-cache pentaho-server; then
    echo -e "${GREEN}✓ Pentaho Server image built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build Pentaho Server image${NC}"
    exit 1
fi

echo ""

# Start PostgreSQL first
echo -e "${BLUE}→ Starting PostgreSQL database...${NC}"
if docker compose up -d postgres; then
    echo -e "${GREEN}✓ PostgreSQL container started${NC}"
else
    echo -e "${RED}✗ Failed to start PostgreSQL${NC}"
    exit 1
fi

# Wait for PostgreSQL to be healthy
echo -e "${BLUE}→ Waiting for PostgreSQL to be ready...${NC}"
for i in {1..30}; do
    if docker compose ps postgres | grep -q "healthy"; then
        echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ PostgreSQL failed to become healthy${NC}"
        echo "  Check logs: docker compose logs postgres"
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo ""

# Start Pentaho Server
echo -e "${BLUE}→ Starting Pentaho Server...${NC}"
echo "  This may take 2-3 minutes for first-time initialization..."
if docker compose up -d pentaho-server; then
    echo -e "${GREEN}✓ Pentaho Server container started${NC}"
else
    echo -e "${RED}✗ Failed to start Pentaho Server${NC}"
    exit 1
fi

# Wait for Pentaho to be ready
echo -e "${BLUE}→ Waiting for Pentaho Server to be ready...${NC}"
echo "  Watching logs for startup completion..."
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if docker compose logs pentaho-server 2>&1 | grep -q "Server startup in"; then
        echo -e "${GREEN}✓ Pentaho Server is ready${NC}"
        break
    fi
    if [ $ELAPSED -eq $TIMEOUT ]; then
        echo -e "${RED}✗ Pentaho Server startup timeout${NC}"
        echo "  Check logs: docker compose logs -f pentaho-server"
        exit 1
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo -n "."
done
echo ""

# ============================================
# Deployment Complete
# ============================================

echo ""
echo "=========================================="
echo -e "${GREEN} Deployment Successful!${NC}"
echo "=========================================="
echo ""
echo "Services are now running:"
echo ""
echo -e "  ${BLUE}Pentaho Server:${NC}"
echo "    URL: http://localhost:${PENTAHO_HTTP_PORT:-8090}/pentaho"
echo "    Login: admin / password"
echo ""
echo -e "  ${BLUE}PostgreSQL Database:${NC}"
echo "    Host: localhost:${POSTGRES_PORT:-5432}"
echo "    Login: postgres / ${POSTGRES_PASSWORD:-password}"
echo ""
echo "Useful commands:"
echo "  View logs:        docker compose logs -f"
echo "  Stop services:    docker compose stop"
echo "  Start services:   docker compose start"
echo "  Restart services: docker compose restart"
echo "  Shutdown:         docker compose down"
echo ""
echo "Helper scripts:"
echo "  Backup database:  ./scripts/backup-postgres.sh"
echo "  Restore database: ./scripts/restore-postgres.sh <backup-file>"
echo "  Validate:         ./scripts/validate-deployment.sh"
echo ""
echo "=========================================="
