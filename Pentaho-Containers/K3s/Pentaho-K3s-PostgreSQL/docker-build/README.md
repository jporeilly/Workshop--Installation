# Building Pentaho Server Docker Image for K3s

## Table of Contents

1. [Introduction](#introduction)
2. [Quick Start](#quick-start)
3. [Directory Structure](#directory-structure)
4. [Prerequisites](#prerequisites)
5. [Dockerfile Features](#dockerfile-features)
6. [Build Arguments](#build-arguments)
7. [Environment Variables](#environment-variables)
8. [Building the Image](#building-the-image)
9. [Plugin Support](#plugin-support)
10. [Testing the Image](#testing-the-image)
11. [Pushing to Registry](#pushing-to-registry)
12. [K3s Integration](#k3s-integration)
13. [Optimization](#optimization)
14. [Troubleshooting](#troubleshooting)
15. [Best Practices](#best-practices)
16. [CI/CD Integration](#cicd-integration)
17. [Additional Resources](#additional-resources)

---

## Introduction

This directory contains a **production-ready Docker image build system** for Pentaho Business Analytics Server 11.0.0.0-237 (Enterprise Edition), designed specifically for K3s deployment.

### Why Build Your Own Image?

- **Customization**: Add custom plugins, themes, or configurations
- **Version Control**: Pin specific Pentaho versions
- **Security**: Control base image and dependencies
- **Compliance**: Meet organizational requirements
- **Optimization**: Remove unnecessary components
- **K3s Integration**: Optimized for Kubernetes workloads

### What's Included

- 🐳 **Production Dockerfile**: Multi-stage build with security best practices
- 🛠️ **Automated Build Script**: `build.sh` with validation and testing
- 🚀 **Entrypoint Scripts**: Intelligent startup with configuration overlay
- 📦 **Plugin Support**: Automatic detection and installation (PAZ, PIR, PDD)
- 📚 **Comprehensive Documentation**: This guide plus examples

### Key Features

✅ **Security**: Non-root user (pentaho, UID 5000)
✅ **Performance**: Optimized multi-stage build (~2.0-2.2 GB)
✅ **Flexibility**: Support for CE/EE, with/without demo content
✅ **Production-Ready**: Based on battle-tested Docker Compose implementation
✅ **K3s Optimized**: Direct integration with project manifests

---

## Quick Start

**Get started in 4 steps:**

### 1. Place Pentaho Package

```bash
cd docker-build

# Copy your Pentaho ZIP to stagedArtifacts/
cp /path/to/pentaho-server-ee-11.0.0.0-237.zip stagedArtifacts/

# Optional: Add plugins
cp /path/to/paz-plugin-ee-11.0.0.0-237.zip stagedArtifacts/

# Verify
ls -lh stagedArtifacts/
```

### 2. Build the Image

**Option A: Using .env Configuration (Recommended)**
```bash
# Copy and customize configuration
cp .env.example .env
nano .env

# Build with .env settings (automatically loads into K3s)
chmod +x build.sh
./build.sh
```

**Option B: Using build.sh with Command-Line Options**
```bash
# Make executable
chmod +x build.sh

# Build with defaults
./build.sh

# Or with options
./build.sh -v 11.0.0.0-237 -e ee
```

**Option C: Direct Docker Build**
```bash
docker build -t pentaho/pentaho-server:11.0.0.0-237 .
```

### 3. Test the Image

```bash
# Run test container
docker run -d \
    --name pentaho-test \
    -p 8080:8080 \
    pentaho/pentaho-server:11.0.0.0-237

# Watch logs (startup takes 3-5 minutes)
docker logs -f pentaho-test

# Access: http://localhost:8080/pentaho
# Credentials: admin / password
```

### 4. Deploy to K3s

```bash
# Option A: Load directly into K3s
docker save pentaho/pentaho-server:11.0.0.0-237 | sudo k3s ctr images import -

# Option B: Push to registry and update deployment
docker tag pentaho/pentaho-server:11.0.0.0-237 registry.company.com/pentaho:11.0
docker push registry.company.com/pentaho:11.0

kubectl set image deployment/pentaho-server \
    pentaho-server=registry.company.com/pentaho:11.0 \
    -n pentaho
```

---

## Directory Structure

```
docker-build/
├── Dockerfile                      # Production multi-stage Dockerfile
├── build.sh                        # Automated build script with validation
├── .dockerignore                   # Build context exclusions
├── README.md                       # This comprehensive guide
├── entrypoint/
│   └── docker-entrypoint.sh       # Container startup script
└── stagedArtifacts/
    ├── README.md                   # Instructions for placing files
    ├── pentaho-server-ee-11.0.0.0-237.zip  (place here)
    ├── paz-plugin-ee-11.0.0.0-237.zip      (optional)
    ├── pir-plugin-ee-11.0.0.0-237.zip      (optional)
    └── pdd-plugin-ee-11.0.0.0-237.zip      (optional)
```

---

## Prerequisites

### Software Requirements

| Software | Version | Purpose |
|----------|---------|---------|
| **Docker** | 20.x or higher | Building and running images |
| **Docker Buildx** | Latest | Multi-platform builds (optional) |
| **K3s** | 1.27+ | Kubernetes deployment (optional) |
| **wget/curl** | Any | Downloading Pentaho (if needed) |
| **unzip** | Any | Extracting archives locally (optional) |

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 8 GB | 16 GB |
| **Disk Space** | 10 GB free | 20 GB free |
| **CPU** | 2 cores | 4+ cores |

### Install Docker

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y docker.io

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group (no sudo required)
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker run hello-world
```

### Obtaining Pentaho Server

**Enterprise Edition (EE):**
- Requires valid license from Hitachi Vantara
- Download from support portal
- Place in `stagedArtifacts/` directory

**Community Edition (CE):**
```bash
# Download from Hitachi Vantara
wget https://privatefilesbucket-community-edition.s3.us-west-2.amazonaws.com/11.0.0.0-237/ce/server/pentaho-server-ce-11.0.0.0-237.zip

# Move to stagedArtifacts/
mv pentaho-server-ce-11.0.0.0-237.zip stagedArtifacts/
```

---

## Dockerfile Features

### Multi-Stage Build Architecture

The Dockerfile uses a **2-stage build** for optimal image size and security:

#### Stage 1: install_unpack
**Purpose**: Extracts and prepares Pentaho Server

- Extracts Pentaho ZIP file
- Detects and installs optional plugins (PAZ, PIR, PDD)
- Removes unnecessary files and demo content (if IS_DEMO=0)
- Prepares clean installation directory

**Key Operations**:
```dockerfile
# Extract main package
RUN unzip pentaho-server-ee-*.zip

# Auto-detect and install plugins
RUN if [ -f paz-plugin-ee-*.zip ]; then \
        unzip paz-plugin-ee-*.zip -d /tmp/paz && \
        mv /tmp/paz/* pentaho-server/pentaho-solutions/system/; \
    fi

# Remove demo content
RUN rm -rf pentaho-server/pentaho-solutions/system/default-content
```

#### Stage 2: pack
**Purpose**: Creates final runtime image

- Based on debian:trixie-slim (lightweight, secure)
- Installs OpenJDK 21 JRE (headless - minimal footprint)
- Creates non-root pentaho user (UID 5000)
- Copies prepared Pentaho from stage 1
- Sets up entrypoint with configuration overlay support

**Security Features**:
```dockerfile
# Non-root user
ENV PENTAHO_UID=5000
RUN groupadd --gid ${PENTAHO_UID} pentaho && \
    useradd --uid ${PENTAHO_UID} --gid pentaho --home-dir /home/pentaho pentaho

USER pentaho
```

### Image Specifications

| Property | Value |
|----------|-------|
| **Base Image** | debian:trixie-slim |
| **Java Version** | OpenJDK 21 JRE (headless) |
| **User** | pentaho (UID 5000, non-root) |
| **Working Directory** | /opt/pentaho/pentaho-server |
| **Exposed Ports** | 8080 (HTTP), 8443 (HTTPS) |
| **Image Size** | 2.0 - 2.2 GB (compressed) |
| **Build Time** | 5-10 minutes |

### What Gets Configured

During container startup, the entrypoint script configures:

1. **JVM Memory**: Heap size based on PENTAHO_MIN_MEMORY and PENTAHO_MAX_MEMORY
2. **Database Connections**: PostgreSQL (or other DB) connection parameters
3. **Timezone**: Container and JVM timezone settings
4. **Configuration Overlay**: Apply custom configurations from mounted volumes
5. **License Files**: Load license if LICENSE_URL is provided (EE only)

---

## Build Arguments

Control the build process with these arguments:

| Argument | Default | Description |
|----------|---------|-------------|
| **INSTALLATION_PATH** | /opt/pentaho | Base installation directory |
| **PENTAHO_VERSION** | 11.0.0.0-xxx | Pentaho version number |
| **PENTAHO_INSTALLER_NAME** | pentaho-server-ee | Package name prefix (ee or ce) |
| **IS_DEMO** | 0 | Include demo content (0=no, 1=yes) |
| **UNPACK_BUILD_IMAGE** | debian:trixie-slim | Stage 1 base image |
| **PACK_BUILD_IMAGE** | debian:trixie-slim | Stage 2 base image |

### Examples

```bash
# Specify version
docker build --build-arg PENTAHO_VERSION=11.0.0.0-237 -t pentaho-server:11.0 .

# Include demo content
docker build --build-arg IS_DEMO=1 -t pentaho-server:demo .

# Community Edition
docker build --build-arg PENTAHO_INSTALLER_NAME=pentaho-server-ce -t pentaho-server-ce:11.0 .

# Custom base image
docker build \
    --build-arg UNPACK_BUILD_IMAGE=ubuntu:24.04 \
    --build-arg PACK_BUILD_IMAGE=ubuntu:24.04 \
    -t pentaho-server:ubuntu .
```

---

## Using .env Configuration Files

### Overview

The `.env` configuration file provides a **centralized way to manage all build and runtime settings**, similar to the Docker Compose deployment. This approach is recommended for:

- **Production environments**: Consistent builds across teams
- **CI/CD pipelines**: Version-controlled configuration
- **Complex configurations**: Multiple settings including licensing, JVM, database
- **Automated workflows**: Build → Test → Push → Deploy in one command

### Quick Setup

```bash
# 1. Copy template
cp .env.example .env

# 2. Edit configuration
nano .env

# 3. Build with configuration
./build.sh
```

### Configuration Categories

The `.env` file is organized into logical sections:

#### 1. Build Configuration
```bash
PENTAHO_VERSION=11.0.0.0-237
EDITION=ee                      # ee or ce
INCLUDE_DEMO=0                  # 0 or 1
IMAGE_TAG=pentaho/pentaho-server:11.0.0.0-237
```

#### 2. Runtime Settings
```bash
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m
PENTAHO_DI_JAVA_OPTIONS=-Dfile.encoding=utf8
TZ=America/New_York
```

#### 3. Database Configuration
```bash
DB_TYPE=postgres
DB_HOST=postgres
DB_PORT=5432
```

#### 4. Enterprise License
```bash
LICENSE_URL=https://company.com/licenses/pentaho-ee.lic
```

#### 5. Automation Actions
```bash
PUSH_TO_REGISTRY=false          # Auto-push after build
LOAD_INTO_K3S=true              # Auto-load into K3s
RUN_TESTS=true                  # Run validation tests
```

#### 6. K3s Integration
```bash
K3S_NAMESPACE=pentaho
K3S_DEPLOYMENT=pentaho-server   # Auto-update deployment
```

### Example Configurations

**Development Environment:**
```bash
PENTAHO_VERSION=11.0.0.0-237
EDITION=ee
INCLUDE_DEMO=1
PENTAHO_MIN_MEMORY=1024m
PENTAHO_MAX_MEMORY=2048m
LOAD_INTO_K3S=true
PUSH_TO_REGISTRY=false
RUN_TESTS=true
```

**Production Environment:**
```bash
PENTAHO_VERSION=11.0.0.0-237
EDITION=ee
INCLUDE_DEMO=0
PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=8192m
LICENSE_URL=https://licenses.company.com/pentaho-ee.lic
LOAD_INTO_K3S=false
PUSH_TO_REGISTRY=true
REGISTRY_URL=harbor.company.com
RUN_TESTS=true
```

### Using build.sh

The `build.sh` script reads the `.env` file and:

1. ✅ **Validates prerequisites** (Docker, files)
2. ✅ **Builds Docker image** with configured settings
3. ✅ **Runs tests** (if enabled)
4. ✅ **Pushes to registry** (if enabled)
5. ✅ **Loads into K3s** (if enabled)
6. ✅ **Updates K3s deployment** (if enabled)
7. ✅ **Sends notifications** (if webhook configured)

**Basic Usage:**
```bash
# Use default .env file
./build.sh

# Use custom .env file
./build.sh --env-file .env.production

# Dry run (show what would be built)
./build.sh --dry-run
```

### Complete Workflow Example

```bash
# 1. Configure
cp .env.example .env
nano .env  # Set LOAD_INTO_K3S=true, LICENSE_URL, etc.

# 2. Build (one command does everything)
./build.sh

# Output:
# ✅ Validates prerequisites
# ✅ Builds image with your settings
# ✅ Runs tests
# ✅ Loads into K3s
# ✅ Updates deployment
# ✅ Shows next steps
```

### Security Notes

⚠️ **Important**: The `.env` file is already in `.dockerignore` and should **NEVER** contain:
- Database passwords (use Kubernetes Secrets)
- API keys
- Private keys or certificates

Use `.env` for build-time configuration only. Runtime secrets go in Kubernetes Secrets.

### Available Options

**Complete Documentation**: See [ENV-CONFIGURATION.md](ENV-CONFIGURATION.md) for detailed explanation of ALL ~40 options.

**Quick Reference** in `.env.example`:
- Build platforms (amd64, arm64)
- BuildKit settings
- Custom base images
- Notification webhooks
- CI/CD integration
- Debug options

**Most Important Options**:
- `PENTAHO_VERSION` - Version number
- `EDITION` - ee or ce
- `INCLUDE_DEMO` - 0 or 1
- `PENTAHO_MIN/MAX_MEMORY` - JVM heap
- `LICENSE_URL` - EE license (optional)
- `PUSH_TO_REGISTRY` - true/false
- `LOAD_INTO_K3S` - true/false

---

## Environment Variables

### Runtime Configuration

Control container behavior with environment variables:

#### JVM Memory Settings

```bash
PENTAHO_MIN_MEMORY=2048m      # Initial heap size (-Xms)
PENTAHO_MAX_MEMORY=4096m      # Maximum heap size (-Xmx)
```

**Guidelines:**
- Development: Min=1024m, Max=2048m
- Testing: Min=2048m, Max=4096m
- Production: Min=4096m, Max=8192m
- Heavy loads: Min=8192m, Max=12288m

**Note**: Container memory limit should be ~1.5x PENTAHO_MAX_MEMORY

#### Database Configuration

```bash
DB_TYPE=postgres              # Database type (postgres, mysql, oracle)
DB_HOST=postgres              # Database hostname or IP
DB_PORT=5432                  # Database port
POSTGRES_PASSWORD=password    # Database password (use Secrets in K8s)
```

#### Pentaho Paths

```bash
INSTALLATION_PATH=/opt/pentaho
PENTAHO_SERVER_PATH=/opt/pentaho/pentaho-server
PENTAHO_HOME=/home/pentaho
```

#### Additional Settings

```bash
TZ=America/New_York                    # Timezone
PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8"  # Java options
SKIP_WEBKITGTK_CHECK=1                 # Skip GTK check (headless)
LICENSE_URL=http://...                  # License file URL (EE only)
```

### Setting Variables at Runtime

**Docker:**
```bash
docker run -d \
    -e PENTAHO_MIN_MEMORY=4096m \
    -e PENTAHO_MAX_MEMORY=8192m \
    -e DB_HOST=postgres \
    -e TZ=America/Los_Angeles \
    pentaho/pentaho-server:11.0
```

**K3s (ConfigMap):**
```yaml
# manifests/configmaps/pentaho-config.yaml
data:
  PENTAHO_MIN_MEMORY: "4096m"
  PENTAHO_MAX_MEMORY: "8192m"
  DB_HOST: "postgres"
  TZ: "America/Los_Angeles"
```

---

## Building the Image

### Method 1: Using build.sh (Recommended)

The included `build.sh` script provides automated building with validation:

```bash
# Make executable
chmod +x build.sh

# View help
./build.sh --help

# Build with defaults (EE, no demo)
./build.sh

# Enterprise Edition with specific version
./build.sh -v 11.0.0.0-237 -e ee

# Community Edition
./build.sh -e ce

# With demo content
./build.sh --demo

# Custom tag
./build.sh -t mycompany/pentaho:production

# Build and push to registry
./build.sh -p
```

**build.sh Features:**
- ✅ Validates Docker installation
- ✅ Checks for required files in stagedArtifacts/
- ✅ Detects plugins automatically
- ✅ Confirms build before proceeding
- ✅ Shows image information after build
- ✅ Tests image for basic functionality
- ✅ Optionally pushes to registry
- ✅ Displays next steps

### Method 2: Direct Docker Build

For more control, use `docker build` directly:

```bash
# Basic build
docker build -t pentaho/pentaho-server:11.0.0.0-237 .

# Build with progress output
docker build --progress=plain -t pentaho/pentaho-server:11.0.0.0-237 .

# With specific version and metadata
docker build \
    --build-arg PENTAHO_VERSION=11.0.0.0-237 \
    --label version=11.0.0.0-237 \
    --label edition=ee \
    --label build-date=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    -t pentaho/pentaho-server:11.0.0.0-237 \
    .

# Multi-platform build
docker buildx create --name multiplatform
docker buildx use multiplatform

docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t pentaho/pentaho-server:11.0.0.0-237 \
    --push \
    .

# With BuildKit for better performance
DOCKER_BUILDKIT=1 docker build \
    --cache-from pentaho/pentaho-server:latest \
    -t pentaho/pentaho-server:11.0.0.0-237 \
    .
```

### Building for Different Editions

#### Enterprise Edition (Default)

```bash
docker build \
    --build-arg PENTAHO_VERSION=11.0.0.0-237 \
    --build-arg PENTAHO_INSTALLER_NAME=pentaho-server-ee \
    -t pentaho/pentaho-server-ee:11.0.0.0-237 \
    .
```

#### Community Edition

```bash
docker build \
    --build-arg PENTAHO_VERSION=11.0.0.0-237 \
    --build-arg PENTAHO_INSTALLER_NAME=pentaho-server-ce \
    -t pentaho/pentaho-server-ce:11.0.0.0-237 \
    .
```

#### With Demo Content

```bash
docker build \
    --build-arg IS_DEMO=1 \
    --build-arg PENTAHO_VERSION=11.0.0.0-237 \
    -t pentaho/pentaho-server:11.0.0.0-237-demo \
    .
```

---

## Plugin Support

The Dockerfile automatically detects and installs optional Pentaho plugins placed in `stagedArtifacts/`.

### Supported Plugins

| Plugin | Filename Pattern | Description |
|--------|-----------------|-------------|
| **PAZ** | paz-plugin-ee-{VERSION}.zip | Pentaho Analyzer (OLAP analysis) |
| **PIR** | pir-plugin-ee-{VERSION}.zip | Pentaho Interactive Reporting |
| **PDD** | pdd-plugin-ee-{VERSION}.zip | Pentaho Dashboard Designer |

### Adding Plugins

```bash
# Place plugin ZIPs in stagedArtifacts/
cd stagedArtifacts/

# Example: Add Analyzer plugin
cp /path/to/paz-plugin-ee-11.0.0.0-237.zip .

# Example: Add all three plugins
cp /path/to/paz-plugin-ee-11.0.0.0-237.zip .
cp /path/to/pir-plugin-ee-11.0.0.0-237.zip .
cp /path/to/pdd-plugin-ee-11.0.0.0-237.zip .

# Verify
ls -lh
```

**Auto-Detection**: During build, the Dockerfile automatically:
1. Detects presence of plugin ZIPs
2. Extracts plugins to temporary directory
3. Moves plugin files to Pentaho system directory
4. Ensures proper permissions
5. Cleans up temporary files

**Manual Installation** (if needed after build):
```bash
# Copy plugin to running container
docker cp paz-plugin-ee-11.0.0.0-237.zip pentaho-test:/tmp/

# Extract in container
docker exec pentaho-test bash -c "cd /tmp && unzip paz-plugin-ee-11.0.0.0-237.zip -d /opt/pentaho/pentaho-server/pentaho-solutions/system/"

# Restart container
docker restart pentaho-test
```

---

## Testing the Image

### Test 1: Basic Container Run

```bash
# Start container
docker run -d \
    --name pentaho-test \
    -p 8080:8080 \
    -e PENTAHO_MIN_MEMORY=2048m \
    -e PENTAHO_MAX_MEMORY=4096m \
    pentaho/pentaho-server:11.0.0.0-237

# Follow logs (startup takes 3-5 minutes)
docker logs -f pentaho-test

# Look for successful startup message:
# "Server startup in [XXXXX] milliseconds"

# Test HTTP endpoint
curl -I http://localhost:8080/pentaho/Login
# Expected: HTTP/1.1 200 OK

# Open in browser
xdg-open http://localhost:8080/pentaho
# Or on Mac: open http://localhost:8080/pentaho

# Cleanup
docker stop pentaho-test
docker rm pentaho-test
```

**Default Credentials:**
- Username: `admin`
- Password: `password`

### Test 2: With PostgreSQL

```bash
# Start PostgreSQL
docker run -d \
    --name postgres-test \
    -e POSTGRES_PASSWORD=password \
    -p 5432:5432 \
    postgres:15

# Wait for PostgreSQL to be ready
sleep 10

# Initialize databases (run init scripts)
docker exec -i postgres-test psql -U postgres < ../manifests/configmaps/postgres-init.yaml

# Start Pentaho linked to PostgreSQL
docker run -d \
    --name pentaho-test \
    --link postgres-test:postgres \
    -p 8080:8080 \
    -e DB_HOST=postgres \
    -e DB_PORT=5432 \
    -e POSTGRES_PASSWORD=password \
    pentaho/pentaho-server:11.0.0.0-237

# Watch logs
docker logs -f pentaho-test

# Cleanup
docker stop pentaho-test postgres-test
docker rm pentaho-test postgres-test
```

### Test 3: Verify Internal Components

```bash
# Check Java version
docker exec pentaho-test java -version

# List Pentaho files
docker exec pentaho-test ls -la /opt/pentaho/pentaho-server

# Check running processes
docker exec pentaho-test ps aux | grep java

# Check disk usage
docker exec pentaho-test df -h

# Check memory
docker exec pentaho-test free -h

# Check logs
docker exec pentaho-test tail -100 /opt/pentaho/pentaho-server/tomcat/logs/catalina.out
```

### Test 4: Health Check

```bash
# Check container health status
docker inspect pentaho-test | grep -A5 Health

# Manual health check
docker exec pentaho-test curl -f http://localhost:8080/pentaho/Login

# Expected: HTTP 200 OK
```

### Test 5: Deploy to K3s

```bash
# Load image into K3s
docker save pentaho/pentaho-server:11.0.0.0-237 | sudo k3s ctr images import -

# Verify image is loaded
sudo k3s ctr images ls | grep pentaho

# Update deployment
kubectl set image deployment/pentaho-server \
    pentaho-server=pentaho/pentaho-server:11.0.0.0-237 \
    -n pentaho

# Watch rollout
kubectl rollout status deployment/pentaho-server -n pentaho

# Watch pods
kubectl get pods -n pentaho -w

# Check logs
kubectl logs -f deployment/pentaho-server -n pentaho
```

---

## Pushing to Registry

### Docker Hub

```bash
# Login
docker login

# Tag image
docker tag pentaho/pentaho-server:11.0.0.0-237 your-username/pentaho-server:11.0.0.0-237
docker tag pentaho/pentaho-server:11.0.0.0-237 your-username/pentaho-server:latest

# Push
docker push your-username/pentaho-server:11.0.0.0-237
docker push your-username/pentaho-server:latest
```

### Private Harbor Registry

```bash
# Login
docker login harbor.company.com

# Tag
docker tag pentaho/pentaho-server:11.0.0.0-237 \
    harbor.company.com/pentaho/pentaho-server:11.0.0.0-237

# Push
docker push harbor.company.com/pentaho/pentaho-server:11.0.0.0-237
```

### AWS ECR

```bash
# Install AWS CLI (if not installed)
sudo apt install awscli

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin \
    123456789012.dkr.ecr.us-east-1.amazonaws.com

# Create repository (if not exists)
aws ecr create-repository \
    --repository-name pentaho/pentaho-server \
    --region us-east-1

# Tag
docker tag pentaho/pentaho-server:11.0.0.0-237 \
    123456789012.dkr.ecr.us-east-1.amazonaws.com/pentaho/pentaho-server:11.0.0.0-237

# Push
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/pentaho/pentaho-server:11.0.0.0-237
```

### Google Container Registry (GCR)

```bash
# Configure Docker auth
gcloud auth configure-docker

# Tag
docker tag pentaho/pentaho-server:11.0.0.0-237 \
    gcr.io/your-project-id/pentaho-server:11.0.0.0-237

# Push
docker push gcr.io/your-project-id/pentaho-server:11.0.0.0-237
```

---

## K3s Integration

### Update Deployment Manifest

Edit `../manifests/pentaho/deployment.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
        - name: pentaho-server
          # Option 1: Local image loaded into K3s
          image: pentaho/pentaho-server:11.0.0.0-237
          imagePullPolicy: IfNotPresent

          # Option 2: From Docker Hub
          # image: your-username/pentaho-server:11.0.0.0-237
          # imagePullPolicy: Always

          # Option 3: From private registry
          # image: harbor.company.com/pentaho/pentaho-server:11.0.0.0-237
          # imagePullPolicy: IfNotPresent
```

### Using Private Registry

**Create image pull secret:**

```bash
# Docker Hub
kubectl create secret docker-registry pentaho-registry-secret \
    --docker-server=docker.io \
    --docker-username=your-username \
    --docker-password=your-password \
    --docker-email=your-email@example.com \
    -n pentaho

# Harbor
kubectl create secret docker-registry pentaho-registry-secret \
    --docker-server=harbor.company.com \
    --docker-username=admin \
    --docker-password=Harbor12345 \
    -n pentaho

# AWS ECR
kubectl create secret docker-registry pentaho-registry-secret \
    --docker-server=123456789012.dkr.ecr.us-east-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region us-east-1) \
    -n pentaho
```

**Update deployment:**

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: pentaho-registry-secret
      containers:
        - name: pentaho-server
          image: harbor.company.com/pentaho/pentaho-server:11.0.0.0-237
          imagePullPolicy: IfNotPresent
```

### Load Image Without Registry

**Best for air-gapped or local development:**

```bash
# Save image to tar file
docker save pentaho/pentaho-server:11.0.0.0-237 -o pentaho-server.tar

# Transfer to K3s node (if remote)
scp pentaho-server.tar k3s-node:/tmp/

# Load into K3s
sudo k3s ctr images import /tmp/pentaho-server.tar

# Verify
sudo k3s ctr images ls | grep pentaho

# Cleanup tar file
rm /tmp/pentaho-server.tar
```

### Deploy Updated Image

```bash
# Apply updated deployment
kubectl apply -f ../manifests/pentaho/deployment.yaml

# Or update image directly
kubectl set image deployment/pentaho-server \
    pentaho-server=pentaho/pentaho-server:11.0.0.0-237 \
    -n pentaho

# Watch rollout
kubectl rollout status deployment/pentaho-server -n pentaho

# Check pods
kubectl get pods -n pentaho

# Describe pod for events
kubectl describe pod <pod-name> -n pentaho

# Check logs
kubectl logs -f deployment/pentaho-server -n pentaho
```

---

## Optimization

### Reduce Image Size

#### 1. Remove Unnecessary Files (Already Done)

The Dockerfile already removes:
- Demo content (when IS_DEMO=0)
- Documentation files
- Sample solutions
- Temporary build files

#### 2. Use .dockerignore

The included `.dockerignore` excludes:
- Version control files (.git)
- Documentation (*.md)
- IDE files (.vscode, .idea)
- Log files (*.log)
- Temporary files (*.tmp)

#### 3. Minimize Layers

```dockerfile
# Bad: Multiple RUN commands create multiple layers
RUN apt-get update
RUN apt-get install -y openjdk-21-jre
RUN apt-get clean

# Good: Single RUN command
RUN apt-get update && \
    apt-get install -y --no-install-recommends openjdk-21-jre && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
```

#### 4. Remove Unnecessary Tomcat Webapps

Add to Dockerfile stage 2 (after COPY):

```dockerfile
# Remove unnecessary Tomcat webapps
RUN rm -rf ${PENTAHO_SERVER_PATH}/tomcat/webapps/docs \
           ${PENTAHO_SERVER_PATH}/tomcat/webapps/examples \
           ${PENTAHO_SERVER_PATH}/tomcat/webapps/host-manager \
           ${PENTAHO_SERVER_PATH}/tomcat/webapps/manager
```

### Build Cache Optimization

```bash
# Use BuildKit cache mounts
DOCKER_BUILDKIT=1 docker build \
    --cache-from pentaho/pentaho-server:latest \
    --cache-to type=local,dest=/tmp/docker-cache \
    --cache-from type=local,src=/tmp/docker-cache \
    -t pentaho/pentaho-server:11.0.0.0-237 \
    .

# Use registry as cache
docker buildx build \
    --cache-from type=registry,ref=your-registry/pentaho-cache \
    --cache-to type=registry,ref=your-registry/pentaho-cache,mode=max \
    -t pentaho/pentaho-server:11.0.0.0-237 \
    --push \
    .
```

### Performance Tuning

#### JVM Optimization

```bash
# Add to CATALINA_OPTS in entrypoint.sh
-XX:+UseG1GC                     # Use G1 garbage collector
-XX:+UseStringDeduplication      # Reduce memory for duplicate strings
-XX:MaxGCPauseMillis=200         # Target max GC pause time
-XX:+OptimizeStringConcat        # Optimize string concatenation
-XX:+UseCompressedOops           # Compress object pointers
```

#### Resource Limits

Set appropriate limits in K3s deployment:

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1"
  limits:
    memory: "6Gi"
    cpu: "4"
```

---

## Troubleshooting

### Issue 1: File Not Found

**Error:**
```
Required file not found: stagedArtifacts/pentaho-server-ee-11.0.0.0-237.zip
```

**Solution:**
```bash
# Check file exists
ls -la stagedArtifacts/

# Verify filename exactly matches
# Should be: pentaho-server-ee-11.0.0.0-237.zip
#         NOT: pentaho-server-11.0.0.0-237.zip

# Check version number matches PENTAHO_VERSION build arg
```

### Issue 2: Permission Denied (Docker)

**Error:**
```
permission denied while trying to connect to Docker daemon
```

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or:
newgrp docker

# Verify
docker ps
```

### Issue 3: Build Hangs at Unzip

**Symptom:** Build appears frozen at "Extracting Pentaho..." step

**Cause:** Large ZIP file extraction (1.5-2 GB)

**Solution:**
```bash
# Be patient! Extraction can take 5-10 minutes

# Monitor in another terminal
docker ps
docker stats

# Check disk I/O
iostat -x 1
```

### Issue 4: Container Exits Immediately

**Check logs:**
```bash
docker logs pentaho-test
```

**Common causes:**
- **Missing Java**: Verify OpenJDK installation in image
- **Permission issues**: Check pentaho user ownership
- **Memory limits**: Increase container memory
- **Port conflicts**: Check if 8080 is already in use

**Debug:**
```bash
# Start with shell
docker run -it --rm \
    --entrypoint /bin/bash \
    pentaho/pentaho-server:11.0.0.0-237

# Inside container:
java -version
ls -la /opt/pentaho/pentaho-server
whoami
id
```

### Issue 5: Out of Memory Errors

**Symptoms:**
```
java.lang.OutOfMemoryError: Java heap space
```

**Solution:**
```bash
# Increase memory
docker run -d \
    --name pentaho-test \
    --memory=8g \
    -p 8080:8080 \
    -e PENTAHO_MIN_MEMORY=4096m \
    -e PENTAHO_MAX_MEMORY=6144m \
    pentaho/pentaho-server:11.0.0.0-237

# In K3s deployment:
resources:
  requests:
    memory: "4Gi"
  limits:
    memory: "8Gi"
```

### Issue 6: Pentaho Starts but UI Not Accessible

**Check:**
```bash
# Container is running
docker ps | grep pentaho

# Port is mapped
docker port pentaho-test

# Tomcat started successfully
docker logs pentaho-test | grep "Server startup"

# HTTP response
curl -I http://localhost:8080/pentaho/Login
```

**Common causes:**
- **Firewall blocking port**: Check firewall rules
- **Port conflict**: Another service using 8080
- **Pentaho still starting**: Wait 5 minutes
- **Wrong URL**: Should be /pentaho not /

**Solution:**
```bash
# Check for port conflicts
sudo netstat -tulpn | grep 8080

# Check Tomcat logs
docker exec pentaho-test tail -100 /opt/pentaho/pentaho-server/tomcat/logs/catalina.out

# Try different port
docker run -d -p 8090:8080 pentaho/pentaho-server:11.0
```

### Issue 7: Out of Disk Space

**Error:**
```
no space left on device
```

**Solution:**
```bash
# Check disk space
df -h

# Clean up Docker
docker system prune -a --volumes

# Remove unused images
docker image prune -a

# Remove stopped containers
docker container prune

# Remove unused volumes
docker volume prune

# Clean up build cache
docker builder prune -a
```

### Issue 8: K3s Can't Pull Image

**Error:**
```
Failed to pull image: ImagePullBackOff
```

**Solution:**
```bash
# For private registries: Create image pull secret
kubectl create secret docker-registry pentaho-registry \
    --docker-server=registry.company.com \
    --docker-username=user \
    --docker-password=pass \
    -n pentaho

# Add to deployment:
spec:
  template:
    spec:
      imagePullSecrets:
        - name: pentaho-registry

# For local images: Load into K3s
docker save pentaho/pentaho-server:11.0 | sudo k3s ctr images import -

# Set imagePullPolicy
spec:
  containers:
    - name: pentaho-server
      image: pentaho/pentaho-server:11.0
      imagePullPolicy: IfNotPresent  # Don't try to pull if image exists locally
```

---

## Best Practices

### Security

1. **Run as Non-Root User** (Already Implemented)
   ```dockerfile
   USER pentaho  # UID 5000
   ```

2. **Don't Include Secrets in Image**
   ```bash
   # Bad: Hardcoded password
   ENV DB_PASSWORD=secret123

   # Good: Use environment variables at runtime
   docker run -e DB_PASSWORD=${DB_PASSWORD} ...

   # Best: Use K8s Secrets
   valueFrom:
     secretKeyRef:
       name: pentaho-secrets
       key: db-password
   ```

3. **Use Specific Tags**
   ```bash
   # Bad: Latest tag changes unpredictably
   image: pentaho-server:latest

   # Good: Specific version
   image: pentaho-server:11.0.0.0-237
   ```

4. **Scan for Vulnerabilities**
   ```bash
   # Using Trivy
   docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
       aquasec/trivy:latest image pentaho/pentaho-server:11.0.0.0-237

   # Using Snyk
   snyk container test pentaho/pentaho-server:11.0.0.0-237
   ```

5. **Keep Base Image Updated**
   ```bash
   # Rebuild regularly to get security patches
   docker build --no-cache -t pentaho-server:11.0 .
   ```

6. **Use Read-Only Root Filesystem** (Advanced)
   ```yaml
   securityContext:
     readOnlyRootFilesystem: true
   volumeMounts:
     - name: temp
       mountPath: /tmp
     - name: logs
       mountPath: /opt/pentaho/pentaho-server/tomcat/logs
   ```

### Performance

1. **JVM Tuning**
   ```bash
   # Adjust heap size based on workload
   PENTAHO_MIN_MEMORY=4096m
   PENTAHO_MAX_MEMORY=8192m

   # Use modern garbage collector
   -XX:+UseG1GC
   -XX:MaxGCPauseMillis=200
   ```

2. **Resource Limits in K8s**
   ```yaml
   resources:
     requests:
       memory: "4Gi"
       cpu: "2"
     limits:
       memory: "8Gi"
       cpu: "4"
   ```

3. **Health Checks** (Already Configured)
   ```yaml
   startupProbe:
     httpGet:
       path: /pentaho/Login
       port: 8080
     initialDelaySeconds: 60
     periodSeconds: 10
     failureThreshold: 30
   ```

4. **Mount Volumes for Data**
   ```yaml
   volumeMounts:
     - name: pentaho-data
       mountPath: /opt/pentaho/pentaho-server/data
     - name: pentaho-solutions
       mountPath: /opt/pentaho/pentaho-server/pentaho-solutions
   ```

### Maintenance

1. **Version All Images**
   ```bash
   # Tag with multiple versions
   docker tag pentaho-server:11.0.0.0-237 pentaho-server:11.0.0
   docker tag pentaho-server:11.0.0.0-237 pentaho-server:11.0
   docker tag pentaho-server:11.0.0.0-237 pentaho-server:11
   ```

2. **Document Changes**
   - Keep a CHANGELOG.md
   - Use Git tags for releases
   - Document custom configurations

3. **Automate Builds**
   - Use CI/CD (GitHub Actions, GitLab CI, Jenkins)
   - Rebuild on security updates
   - Test before deploying

4. **Monitor Image Size**
   ```bash
   # Track image size over time
   docker images pentaho-server --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
   ```

---

## CI/CD Integration

### GitHub Actions Example

`.github/workflows/build-pentaho.yml`:

```yaml
name: Build Pentaho Image

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Download Pentaho package
        run: |
          # Download from secure location (artifact storage, S3, etc.)
          # Example: aws s3 cp s3://pentaho-artifacts/pentaho-server-ee-11.0.0.0-237.zip docker-build/stagedArtifacts/

      - name: Build image
        working-directory: docker-build
        run: |
          docker build \
            --build-arg PENTAHO_VERSION=${{ steps.version.outputs.VERSION }} \
            --label version=${{ steps.version.outputs.VERSION }} \
            --label build-date=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
            --label git-commit=${{ github.sha }} \
            -t ${{ secrets.DOCKERHUB_USERNAME }}/pentaho-server:${{ steps.version.outputs.VERSION }} \
            -t ${{ secrets.DOCKERHUB_USERNAME }}/pentaho-server:latest \
            .

      - name: Test image
        run: |
          docker run -d --name pentaho-test -p 8080:8080 \
            ${{ secrets.DOCKERHUB_USERNAME }}/pentaho-server:${{ steps.version.outputs.VERSION }}
          sleep 180
          curl -f http://localhost:8080/pentaho/Login || exit 1
          docker stop pentaho-test

      - name: Push to Docker Hub
        run: |
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/pentaho-server:${{ steps.version.outputs.VERSION }}
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/pentaho-server:latest

      - name: Scan for vulnerabilities
        run: |
          docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image \
            ${{ secrets.DOCKERHUB_USERNAME}}/pentaho-server:${{ steps.version.outputs.VERSION }}
```

### GitLab CI Example

`.gitlab-ci.yml`:

```yaml
stages:
  - build
  - test
  - push

variables:
  IMAGE_NAME: registry.gitlab.com/$CI_PROJECT_PATH/pentaho-server
  PENTAHO_VERSION: "11.0.0.0-237"

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - cd docker-build
    - docker build -t $IMAGE_NAME:$CI_COMMIT_TAG -t $IMAGE_NAME:latest .
  only:
    - tags

test:
  stage: test
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker run -d --name pentaho-test -p 8080:8080 $IMAGE_NAME:$CI_COMMIT_TAG
    - sleep 180
    - apk add --no-cache curl
    - curl -f http://localhost:8080/pentaho/Login
  only:
    - tags

push:
  stage: push
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker push $IMAGE_NAME:$CI_COMMIT_TAG
    - docker push $IMAGE_NAME:latest
  only:
    - tags
```

---

## Additional Resources

### Project Documentation

- [../WORKSHOP-SINGLE-NODE.md](../WORKSHOP-SINGLE-NODE.md) - Complete single-node K3s deployment guide
- [../WORKSHOP-MULTI-NODE.md](../WORKSHOP-MULTI-NODE.md) - Multi-node production cluster guide
- [../README.md](../README.md) - Main project README
- [../deploy.sh](../deploy.sh) - Automated K3s deployment script
- [stagedArtifacts/README.md](stagedArtifacts/README.md) - Instructions for placing Pentaho packages

### External Resources

- **Pentaho**: [Official Documentation](https://help.hitachivantara.com/Documentation/Pentaho)
- **Docker**: [Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- **K3s**: [Official Docs](https://docs.k3s.io/)
- **Kubernetes**: [Container Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

### Technical Specifications

#### Resource Sizing Guide

| Users | CPU Cores | Memory | Disk Space |
|-------|-----------|--------|------------|
| 1-10 | 2 | 4 GB | 20 GB |
| 10-50 | 4 | 8 GB | 50 GB |
| 50-100 | 8 | 16 GB | 100 GB |
| 100+ | 16+ | 32+ GB | 200+ GB |

#### Useful Commands Reference

```bash
# Build image
docker build -t pentaho-server:11.0 .

# Run container
docker run -d -p 8080:8080 pentaho-server:11.0

# View logs
docker logs -f container-name

# Execute commands
docker exec -it container-name bash

# Inspect image
docker inspect pentaho-server:11.0

# View history
docker history pentaho-server:11.0

# Push to registry
docker push registry/pentaho-server:11.0

# Remove image
docker rmi pentaho-server:11.0

# Prune unused images
docker image prune -a

# Load into K3s
docker save pentaho-server:11.0 | sudo k3s ctr images import -
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| **2.0** | 2026-01-26 | Consolidated documentation from BUILD-PENTAHO-IMAGE.md and DOCKER-BUILD-SUMMARY.md |
| 1.0 | 2026-01-26 | Initial version with production Dockerfile |

---

## Conclusion

You now have everything needed to build, test, and deploy a production-ready Pentaho Server Docker image for K3s!

### Quick Summary

1. **Place Files**: Copy Pentaho ZIP (and optional plugins) to `stagedArtifacts/`
2. **Build**: Run `./build.sh` or `docker build`
3. **Test**: Verify locally with `docker run`
4. **Deploy**: Push to registry or load into K3s

### Next Steps

1. ✅ Build your first image using `./build.sh`
2. ✅ Test locally with Docker
3. ✅ Push to registry (optional)
4. ✅ Deploy to K3s using workshops
5. ✅ Monitor and optimize

### Need Help?

- **Quick Start Issues**: Re-read [Quick Start](#quick-start) section
- **Build Problems**: Check [Troubleshooting](#troubleshooting) section
- **K3s Deployment**: Follow [WORKSHOP-SINGLE-NODE.md](../WORKSHOP-SINGLE-NODE.md)
- **Production Setup**: See [WORKSHOP-MULTI-NODE.md](../WORKSHOP-MULTI-NODE.md)

---

**Document Version**: 2.0
**Last Updated**: 2026-01-26
**Tested With**: Pentaho 11.0.0.0-237, Docker 24.x, K3s 1.28+

**Ready to build?** Run: `./build.sh`
