# .env Configuration Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Configuration Categories](#configuration-categories)
4. [Build Configuration](#build-configuration)
5. [Runtime Configuration](#runtime-configuration)
6. [Database Configuration](#database-configuration)
7. [Enterprise License](#enterprise-license)
8. [Registry Configuration](#registry-configuration)
9. [K3s Integration](#k3s-integration)
10. [Build Options](#build-options)
11. [Testing Options](#testing-options)
12. [Cleanup Options](#cleanup-options)
13. [Notification Options](#notification-options)
14. [Custom Configuration Overlays](#custom-configuration-overlays)
15. [Development & Debug Options](#development--debug-options)
16. [Common Configurations](#common-configurations)
17. [Best Practices](#best-practices)
18. [Troubleshooting](#troubleshooting)

---

## Introduction

The `.env` file provides a **centralized configuration system** for building Pentaho Docker images. Instead of passing multiple command-line arguments, you configure everything in one file.

### Why Use .env?

✅ **Centralized Configuration** - All settings in one place
✅ **Version Control Friendly** - Check `.env.example` into git, keep `.env` local
✅ **Consistent Builds** - Same configuration across team members
✅ **CI/CD Ready** - Easy integration with pipelines
✅ **Familiar Pattern** - Same approach as Docker Compose project

### Quick Start

```bash
# 1. Copy template
cp .env.example .env

# 2. Edit configuration
nano .env

# 3. Build with configuration
./build.sh
```

---

## Getting Started

### File Structure

```
docker-build/
├── .env.example     # Template with all options (check into git)
├── .env             # Your local configuration (DO NOT commit)
└── build.sh         # Build script that reads .env
```

### Basic Workflow

```bash
# Create your configuration
cp .env.example .env

# Customize for your environment
nano .env

# Build image
./build.sh

# Use different configuration
./build.sh --env-file .env.production
```

---

## Configuration Categories

The `.env` file is organized into 12 logical categories:

| Category | Purpose | Required |
|----------|---------|----------|
| **Build Configuration** | Version, edition, demo content | Yes |
| **Runtime Configuration** | JVM memory, timezone | Yes |
| **Database Configuration** | Database connection settings | Yes |
| **Enterprise License** | EE license installation | Optional |
| **Registry Configuration** | Docker registry push settings | Optional |
| **K3s Integration** | K3s import and deployment | Optional |
| **Build Options** | BuildKit, platforms, caching | Optional |
| **Testing Options** | Test execution settings | Optional |
| **Cleanup Options** | Post-build cleanup | Optional |
| **Notification Options** | Webhook notifications | Optional |
| **Custom Overlays** | Custom configuration files | Optional |
| **Debug Options** | Troubleshooting settings | Optional |

---

## Build Configuration

Controls what gets built into the Docker image.

### PENTAHO_VERSION

**Type**: String
**Default**: `11.0.0.0-237`
**Required**: Yes

Pentaho version number. Must match the ZIP filename in `stagedArtifacts/`.

```bash
PENTAHO_VERSION=11.0.0.0-237
```

**Important**: The ZIP file must be named:
- EE: `pentaho-server-ee-11.0.0.0-237.zip`
- CE: `pentaho-server-ce-11.0.0.0-237.zip`

### EDITION

**Type**: String (`ee` or `ce`)
**Default**: `ee`
**Required**: Yes

Pentaho edition to build.

```bash
# Enterprise Edition
EDITION=ee

# Community Edition
EDITION=ce
```

**Differences**:
- **EE**: Full features, requires license, commercial support
- **CE**: Open source, no license needed, community support

### INCLUDE_DEMO

**Type**: Integer (`0` or `1`)
**Default**: `0`
**Required**: Yes

Include demo content (sample reports, dashboards, data).

```bash
# Include demo content
INCLUDE_DEMO=1

# Production build without demo
INCLUDE_DEMO=0
```

**Demo Content Includes**:
- Steel Wheels sample database
- Sample reports and dashboards
- Tutorial content
- Example transformations

**Image Size Impact**:
- With demo: ~3.3 GB
- Without demo: ~2.0 GB

### IMAGE_TAG

**Type**: String
**Default**: `pentaho/pentaho-server:11.0.0.0-237`
**Required**: Yes

Docker image tag. For registries, include the registry URL.

```bash
# Local image
IMAGE_TAG=pentaho/pentaho-server:11.0.0.0-237

# Docker Hub
IMAGE_TAG=username/pentaho-server:11.0.0.0-237

# Private Registry
IMAGE_TAG=harbor.company.com/pentaho/pentaho-server:11.0.0.0-237
```

### IMAGE_TAG_LATEST

**Type**: String
**Default**: (empty)
**Required**: No

Additional tag for "latest" version.

```bash
IMAGE_TAG_LATEST=pentaho/pentaho-server:latest
```

Creates two tags:
- `pentaho/pentaho-server:11.0.0.0-237`
- `pentaho/pentaho-server:latest`

### IMAGE_TAG_MAJOR

**Type**: String
**Default**: (empty)
**Required**: No

Additional tag for major version.

```bash
IMAGE_TAG_MAJOR=pentaho/pentaho-server:11
```

Creates three tags:
- `pentaho/pentaho-server:11.0.0.0-237` (specific)
- `pentaho/pentaho-server:latest` (latest)
- `pentaho/pentaho-server:11` (major version)

### INSTALLATION_PATH

**Type**: String
**Default**: `/opt/pentaho`
**Required**: No

Base installation directory inside container.

```bash
INSTALLATION_PATH=/opt/pentaho
```

Results in:
- Installation: `/opt/pentaho`
- Pentaho Server: `/opt/pentaho/pentaho-server`

**Note**: Only change if you have specific requirements.

### UNPACK_BUILD_IMAGE

**Type**: String
**Default**: `debian:trixie-slim`
**Required**: No

Base image for build stage 1 (unpack).

```bash
UNPACK_BUILD_IMAGE=debian:trixie-slim
```

### PACK_BUILD_IMAGE

**Type**: String
**Default**: `debian:trixie-slim`
**Required**: No

Base image for build stage 2 (runtime).

```bash
PACK_BUILD_IMAGE=debian:trixie-slim
```

**Alternative Base Images**:
```bash
# Ubuntu-based
PACK_BUILD_IMAGE=ubuntu:24.04

# Debian bookworm
PACK_BUILD_IMAGE=debian:bookworm-slim
```

---

## Runtime Configuration

Settings that affect container behavior at runtime.

### PENTAHO_MIN_MEMORY

**Type**: String (Java memory format)
**Default**: `2048m`
**Required**: Yes

Initial JVM heap size (-Xms).

```bash
PENTAHO_MIN_MEMORY=2048m
```

**Recommendations**:
- **Development**: `1024m`
- **Testing**: `2048m`
- **Production**: `4096m`
- **Heavy Load**: `8192m`

**Important**: Set equal to `PENTAHO_MAX_MEMORY` to avoid heap resizing overhead.

### PENTAHO_MAX_MEMORY

**Type**: String (Java memory format)
**Default**: `4096m`
**Required**: Yes

Maximum JVM heap size (-Xmx).

```bash
PENTAHO_MAX_MEMORY=4096m
```

**Guidelines**:
- Must be less than container memory limit
- Container limit should be ~1.5x this value
- Leave room for non-heap memory (threads, native, etc.)

**Example Sizing**:
```bash
# For 8GB container
PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=6144m

# K8s resources
resources:
  limits:
    memory: "8Gi"
```

### PENTAHO_DI_JAVA_OPTIONS

**Type**: String (quoted if contains spaces)
**Default**: `"-Dfile.encoding=utf8 -Djava.awt.headless=true"`
**Required**: No

Additional JVM options.

```bash
PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 -Djava.awt.headless=true"
```

**Common Options**:
```bash
# Performance tuning
PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 -Djava.awt.headless=true -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Debug mode
PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8044"

# Custom properties
PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 -Dmy.custom.property=value"
```

**Important**: Always quote values with spaces!

### TZ

**Type**: String (IANA timezone)
**Default**: `America/New_York`
**Required**: Yes

Container and JVM timezone.

```bash
TZ=America/New_York
```

**Common Timezones**:
```bash
TZ=America/New_York      # Eastern Time
TZ=America/Chicago       # Central Time
TZ=America/Denver        # Mountain Time
TZ=America/Los_Angeles   # Pacific Time
TZ=Europe/London         # GMT/BST
TZ=Europe/Paris          # CET/CEST
TZ=Asia/Tokyo            # JST
TZ=UTC                   # Coordinated Universal Time
```

**Impact**:
- Scheduled job execution times
- Report timestamps
- Log file timestamps
- Database date/time operations

---

## Database Configuration

Database connection settings for Pentaho repositories.

### DB_TYPE

**Type**: String
**Default**: `postgres`
**Required**: Yes

Database type.

```bash
DB_TYPE=postgres
```

**Supported Values**:
- `postgres` - PostgreSQL
- `mysql` - MySQL/MariaDB
- `oracle` - Oracle Database
- `mssql` - Microsoft SQL Server

### DB_HOST

**Type**: String
**Default**: `postgres`
**Required**: Yes

Database hostname or IP address.

```bash
# Kubernetes service name (most common)
DB_HOST=postgres

# External database
DB_HOST=db.company.com

# IP address
DB_HOST=192.168.1.100
```

**In Kubernetes**: Use service name, resolves to `postgres.pentaho.svc.cluster.local`

### DB_PORT

**Type**: Integer
**Default**: `5432`
**Required**: Yes

Database port number.

```bash
DB_PORT=5432
```

**Default Ports**:
- PostgreSQL: `5432`
- MySQL: `3306`
- Oracle: `1521`
- SQL Server: `1433`

### Database Names & Users

**Note**: These are informational only. Actual database configuration is in:
- K8s: `manifests/configmaps/postgres-init.yaml`
- Container: `/docker-entrypoint-init/` overlays

**Pentaho uses THREE databases**:
1. **jackrabbit** - Content repository (reports, dashboards, files)
2. **quartz** - Job scheduling and triggers
3. **hibernate** - User/role management, audit data

**Database Users**:
- `jcr_user` - JackRabbit content repository
- `pentaho_user` - Quartz scheduler
- `hibuser` - Hibernate repository

**Security**: Passwords are stored in Kubernetes Secrets, NOT in .env file.

---

## Enterprise License

Optional automatic license installation for Enterprise Edition.

### LICENSE_URL

**Type**: String (URL)
**Default**: (empty)
**Required**: No (EE only)

URL to download Pentaho EE license file.

```bash
LICENSE_URL=https://company.com/licenses/pentaho-ee.lic
```

**Supported Protocols**:
- `https://` - HTTPS URL
- `http://` - HTTP URL
- `file://` - Local file path

**Examples**:
```bash
# HTTPS (recommended)
LICENSE_URL=https://licenses.company.com/pentaho/pentaho-ee.lic

# Internal server
LICENSE_URL=http://internal-server/licenses/pentaho.lic

# S3 presigned URL
LICENSE_URL=https://bucket.s3.amazonaws.com/pentaho.lic?X-Amz-Signature=...
```

**How it Works**:
1. License URL set in .env
2. Container starts
3. Entrypoint script checks for license
4. Downloads from URL
5. Installs to `~/.pentaho/.elmLicInfo.plt`
6. EE features enabled

**Important**:
- License is installed on **first container start**
- Not part of image (good for security)
- Can be updated without rebuilding image

---

## Registry Configuration

Settings for pushing images to Docker registries.

### PUSH_TO_REGISTRY

**Type**: Boolean (`true` or `false`)
**Default**: `false`
**Required**: Yes

Enable automatic push to registry after build.

```bash
# Don't push (local K3s only)
PUSH_TO_REGISTRY=false

# Push to registry
PUSH_TO_REGISTRY=true
```

**When to Use**:
- `false` - Single-node K3s, local development
- `true` - Multi-node clusters, production, CI/CD

### REGISTRY_URL

**Type**: String
**Default**: (empty)
**Required**: If PUSH_TO_REGISTRY=true

Docker registry URL.

```bash
# Docker Hub
REGISTRY_URL=docker.io

# Private Harbor
REGISTRY_URL=harbor.company.com

# AWS ECR
REGISTRY_URL=123456789012.dkr.ecr.us-east-1.amazonaws.com

# Google GCR
REGISTRY_URL=gcr.io

# Azure ACR
REGISTRY_URL=myregistry.azurecr.io
```

### REGISTRY_USERNAME

**Type**: String
**Default**: (empty)
**Required**: If PUSH_TO_REGISTRY=true

Registry username.

```bash
# Docker Hub
REGISTRY_USERNAME=your-dockerhub-username

# Harbor
REGISTRY_USERNAME=admin

# AWS ECR
REGISTRY_USERNAME=AWS

# GCR (use token)
REGISTRY_USERNAME=_json_key
```

### REGISTRY_PASSWORD

**Type**: String
**Default**: (empty)
**Required**: If PUSH_TO_REGISTRY=true

Registry password or token.

```bash
# Docker Hub (use access token, not password!)
REGISTRY_PASSWORD=dckr_pat_abc123...

# Harbor
REGISTRY_PASSWORD=Harbor12345

# AWS ECR (get token first)
REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)
```

**Security Warning**:
- Don't commit .env with passwords!
- Use access tokens instead of passwords
- For CI/CD, use secrets/environment variables

---

## K3s Integration

Settings for K3s image import and deployment.

### LOAD_INTO_K3S

**Type**: Boolean (`true` or `false`)
**Default**: `false`
**Required**: No

Automatically load image into K3s after build.

```bash
# Load into K3s (recommended for single-node)
LOAD_INTO_K3S=true

# Don't load (when using registry)
LOAD_INTO_K3S=false
```

**How it Works**:
```bash
docker save IMAGE_TAG | sudo k3s ctr images import -
```

**When to Use**:
- `true` - Single-node K3s, local development, fast iteration
- `false` - Multi-node clusters (use registry instead)

**Note**: Requires sudo access. Script will prompt for password.

### K3S_NAMESPACE

**Type**: String
**Default**: `pentaho`
**Required**: If updating deployment

Kubernetes namespace for deployment.

```bash
K3S_NAMESPACE=pentaho
```

### K3S_DEPLOYMENT

**Type**: String
**Default**: `pentaho-server`
**Required**: If updating deployment

Deployment name to update with new image.

```bash
K3S_DEPLOYMENT=pentaho-server
```

**Auto-Update Deployment**:
When both `LOAD_INTO_K3S=true` and `K3S_DEPLOYMENT` are set, the script will:
1. Build image
2. Load into K3s
3. Update deployment: `kubectl set image deployment/pentaho-server pentaho-server=IMAGE_TAG`
4. Watch rollout status

---

## Build Options

Advanced build configuration.

### USE_BUILDKIT

**Type**: Boolean (`true` or `false`)
**Default**: `true`
**Required**: No

Enable Docker BuildKit for better performance.

```bash
USE_BUILDKIT=true
```

**Benefits**:
- Parallel build stages
- Better caching
- Faster builds
- Progress output

**Disable if**:
- Using older Docker versions
- Compatibility issues

### BUILD_PLATFORM

**Type**: String
**Default**: `linux/amd64`
**Required**: No

Target platform architecture.

```bash
# Intel/AMD 64-bit (most common)
BUILD_PLATFORM=linux/amd64

# ARM 64-bit (Raspberry Pi, Apple Silicon)
BUILD_PLATFORM=linux/arm64

# Multi-platform
BUILD_PLATFORM=linux/amd64,linux/arm64
```

**Multi-Platform Builds**:
```bash
BUILD_PLATFORM=linux/amd64,linux/arm64
```
Requires Docker Buildx with QEMU.

### NO_CACHE

**Type**: Boolean (`true` or `false`)
**Default**: `false`
**Required**: No

Force clean build without cache.

```bash
# Use cache (faster)
NO_CACHE=false

# Force clean build
NO_CACHE=true
```

**When to Use**:
- `true` - After system updates, troubleshooting, production builds
- `false` - Development, fast iteration

### VERBOSE

**Type**: Boolean (`true` or `false`)
**Default**: `false`
**Required**: No

Show detailed build output.

```bash
# Normal output
VERBOSE=false

# Detailed output
VERBOSE=true
```

Adds `--progress=plain` to docker build.

---

## Testing Options

Control post-build validation tests.

### RUN_TESTS

**Type**: Boolean (`true` or `false`)
**Default**: `true`
**Required**: No

Run validation tests after build.

```bash
RUN_TESTS=true
```

**Tests Performed**:
1. **Java Version Check** - Verify OpenJDK 21 installed
2. **File Verification** - Confirm Pentaho files exist
3. **Directory Structure** - Validate installation paths

**Disable for**:
- CI/CD pipelines with separate test stage
- Very fast builds without validation

### TEST_TIMEOUT

**Type**: Integer (seconds)
**Default**: `300`
**Required**: No

Maximum time for tests to complete.

```bash
TEST_TIMEOUT=300
```

---

## Cleanup Options

Post-build cleanup settings.

### CLEANUP_INTERMEDIATE

**Type**: Boolean (`true` or `false`)
**Default**: `true`
**Required**: No

Remove intermediate build images.

```bash
CLEANUP_INTERMEDIATE=true
```

Cleans up dangling `<none>` images from multi-stage builds.

### CLEANUP_DANGLING

**Type**: Boolean (`true` or `false`)
**Default**: `false`
**Required**: No

Remove all dangling images.

```bash
CLEANUP_DANGLING=false
```

Runs `docker image prune -f` after build.

---

## Notification Options

Webhook notifications for build completion.

### SEND_NOTIFICATION

**Type**: Boolean (`true` or `false`)
**Default**: `false`
**Required**: No

Send notification after build.

```bash
SEND_NOTIFICATION=true
```

### NOTIFICATION_WEBHOOK_URL

**Type**: String (URL)
**Default**: (empty)
**Required**: If SEND_NOTIFICATION=true

Webhook URL for notifications.

```bash
# Slack
NOTIFICATION_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

# Discord
NOTIFICATION_WEBHOOK_URL=https://discord.com/api/webhooks/YOUR/WEBHOOK

# Microsoft Teams
NOTIFICATION_WEBHOOK_URL=https://outlook.office.com/webhook/YOUR/WEBHOOK
```

**Notification Includes**:
- Build status (success/failure)
- Pentaho version
- Edition
- Image tag
- Image size

---

## Custom Configuration Overlays

Inject custom configuration files into containers.

### CUSTOM_CONFIG_PATH

**Type**: String (directory path)
**Default**: (empty)
**Required**: No

Path to custom configuration directory.

```bash
CUSTOM_CONFIG_PATH=/path/to/custom-configs
```

**How it Works**:
1. Files in `CUSTOM_CONFIG_PATH` are copied to `/docker-entrypoint-init/` in image
2. On container start, files are copied to Pentaho installation
3. Allows customizing:
   - Database connections
   - JDBC drivers
   - Spring Security config
   - Tomcat settings
   - Custom properties

**Example Structure**:
```
custom-configs/
├── 1_drivers/
│   └── mysql-connector.jar
├── 2_repository/
│   ├── hibernate.xml
│   ├── jackrabbit.xml
│   └── quartz.properties
├── 3_security/
│   └── applicationContext-spring-security.xml
└── 4_others/
    └── server.xml
```

---

## Development & Debug Options

Troubleshooting and debugging settings.

### DEBUG

**Type**: Boolean (`true` or `false`)
**Default**: `false`
**Required**: No

Enable debug output.

```bash
DEBUG=true
```

**Shows**:
- Full docker build command
- All build arguments
- Environment variables
- Detailed execution flow

### PRESERVE_BUILD_CONTEXT

**Type**: Boolean (`true` or `false`)
**Default**: `false`
**Required**: No

Keep temporary build files for debugging.

```bash
PRESERVE_BUILD_CONTEXT=true
```

Useful for troubleshooting build failures.

---

## Common Configurations

### Development Environment

```bash
# .env for development
PENTAHO_VERSION=11.0.0.0-237
EDITION=ee
INCLUDE_DEMO=1                    # Include samples
IMAGE_TAG=pentaho/pentaho-server:dev

PENTAHO_MIN_MEMORY=1024m          # Lower memory
PENTAHO_MAX_MEMORY=2048m
TZ=America/New_York

DB_TYPE=postgres
DB_HOST=postgres
DB_PORT=5432

LICENSE_URL=                      # No license needed

PUSH_TO_REGISTRY=false            # Local only
LOAD_INTO_K3S=true               # Auto-load
RUN_TESTS=true

K3S_NAMESPACE=pentaho
K3S_DEPLOYMENT=pentaho-server

USE_BUILDKIT=true
NO_CACHE=false                    # Use cache
DEBUG=false
```

### Production Environment

```bash
# .env.production
PENTAHO_VERSION=11.0.0.0-237
EDITION=ee
INCLUDE_DEMO=0                    # No demos
IMAGE_TAG=harbor.company.com/pentaho/pentaho-server:11.0.0.0-237
IMAGE_TAG_LATEST=harbor.company.com/pentaho/pentaho-server:latest

PENTAHO_MIN_MEMORY=4096m          # Production memory
PENTAHO_MAX_MEMORY=8192m
PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 -Djava.awt.headless=true -XX:+UseG1GC"
TZ=America/New_York

DB_TYPE=postgres
DB_HOST=postgres.pentaho.svc.cluster.local
DB_PORT=5432

LICENSE_URL=https://licenses.company.com/pentaho-ee.lic

PUSH_TO_REGISTRY=true            # Push to registry
REGISTRY_URL=harbor.company.com
REGISTRY_USERNAME=admin
REGISTRY_PASSWORD=${HARBOR_PASSWORD}  # From env var

LOAD_INTO_K3S=false              # Pull from registry
RUN_TESTS=true

USE_BUILDKIT=true
NO_CACHE=false
SEND_NOTIFICATION=true
NOTIFICATION_WEBHOOK_URL=${SLACK_WEBHOOK}
```

### CI/CD Pipeline

```bash
# .env.ci
PENTAHO_VERSION=${CI_VERSION}
EDITION=ee
INCLUDE_DEMO=0
IMAGE_TAG=${REGISTRY_URL}/pentaho-server:${CI_COMMIT_TAG}

PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=8192m
TZ=UTC

DB_TYPE=postgres
DB_HOST=postgres
DB_PORT=5432

LICENSE_URL=${LICENSE_URL}

PUSH_TO_REGISTRY=true
REGISTRY_URL=${REGISTRY_URL}
REGISTRY_USERNAME=${REGISTRY_USERNAME}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD}

LOAD_INTO_K3S=false
RUN_TESTS=true

USE_BUILDKIT=true
NO_CACHE=true                    # Always clean build
SEND_NOTIFICATION=true
NOTIFICATION_WEBHOOK_URL=${SLACK_WEBHOOK}
```

---

## Best Practices

### Security

1. **Never Commit .env**
   ```bash
   # Add to .gitignore
   echo ".env" >> .gitignore
   ```

2. **Use Access Tokens**
   ```bash
   # Not passwords!
   REGISTRY_PASSWORD=dckr_pat_abc123...  # Good
   REGISTRY_PASSWORD=MyPassword123        # Bad
   ```

3. **Separate Secrets**
   ```bash
   # Build-time config in .env
   PENTAHO_VERSION=11.0.0.0-237

   # Runtime secrets in K8s Secrets
   kubectl create secret generic pentaho-secrets \
       --from-literal=db-password=secret123
   ```

4. **Use Environment Variables for CI/CD**
   ```bash
   # In .env.ci
   REGISTRY_PASSWORD=${CI_REGISTRY_PASSWORD}
   ```

### Performance

1. **Use BuildKit**
   ```bash
   USE_BUILDKIT=true
   ```

2. **Enable Caching**
   ```bash
   NO_CACHE=false  # Most of the time
   ```

3. **Match Memory Settings**
   ```bash
   # Set min = max to avoid resizing
   PENTAHO_MIN_MEMORY=4096m
   PENTAHO_MAX_MEMORY=4096m
   ```

### Maintainability

1. **Document Your .env**
   ```bash
   # Purpose: Production build for US East region
   # Owner: DevOps Team
   # Last Updated: 2026-01-26
   ```

2. **Use Descriptive Tags**
   ```bash
   IMAGE_TAG=harbor.company.com/pentaho/pentaho-server:11.0.0.0-237-prod-us-east
   ```

3. **Version Your Configurations**
   ```bash
   .env.dev
   .env.staging
   .env.production
   .env.production.eu
   ```

### Testing

1. **Always Test Builds**
   ```bash
   RUN_TESTS=true
   ```

2. **Use Dry Run**
   ```bash
   ./build.sh --dry-run
   ```

3. **Verify Registry Credentials**
   ```bash
   docker login ${REGISTRY_URL}
   ```

---

## Troubleshooting

### Issue: "command not found" Error

```bash
# Error
.env: line 24: -Djava.awt.headless=true: command not found
```

**Cause**: Values with spaces must be quoted.

**Fix**:
```bash
# Wrong
PENTAHO_DI_JAVA_OPTIONS=-Dfile.encoding=utf8 -Djava.awt.headless=true

# Correct
PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 -Djava.awt.headless=true"
```

### Issue: File Not Found

```bash
# Error
File not found: stagedArtifacts/pentaho-server-ee-11.0.0.0-237.zip
```

**Solutions**:
1. Check filename matches `PENTAHO_VERSION` and `EDITION`
2. Verify file is in `stagedArtifacts/` directory
3. Check for typos in version number

### Issue: Push Failed - Unauthorized

```bash
# Error
push access denied, repository does not exist or may require authorization
```

**Solutions**:
1. Login manually first:
   ```bash
   docker login ${REGISTRY_URL}
   ```

2. Check credentials in .env

3. Create repository in registry

4. Verify permissions

### Issue: K3s Import Failed

```bash
# Error
sudo: a password is required
```

**Solutions**:
1. Run import manually:
   ```bash
   docker save IMAGE_TAG | sudo k3s ctr images import -
   ```

2. Configure sudo without password:
   ```bash
   echo "$USER ALL=(ALL) NOPASSWD: /usr/local/bin/k3s" | sudo tee /etc/sudoers.d/k3s
   ```

3. Disable auto-load:
   ```bash
   LOAD_INTO_K3S=false
   ```

### Issue: Build Fails - Out of Memory

**Solutions**:
1. Increase Docker memory (Docker Desktop settings)

2. Build without demo:
   ```bash
   INCLUDE_DEMO=0
   ```

3. Clean up Docker:
   ```bash
   docker system prune -a
   ```

### Issue: Wrong Image Built

**Check**:
```bash
# Preview build
./build.sh --dry-run

# Check loaded .env
cat .env | grep -v "^#" | grep -v "^$"
```

---

## Quick Reference

### Minimal .env (Development)

```bash
PENTAHO_VERSION=11.0.0.0-237
EDITION=ee
INCLUDE_DEMO=1
IMAGE_TAG=pentaho/pentaho-server:11.0.0.0-237
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m
TZ=America/New_York
DB_TYPE=postgres
DB_HOST=postgres
DB_PORT=5432
PUSH_TO_REGISTRY=false
LOAD_INTO_K3S=true
RUN_TESTS=true
K3S_NAMESPACE=pentaho
K3S_DEPLOYMENT=pentaho-server
USE_BUILDKIT=true
```

### Full .env Template

See [.env.example](.env.example) for complete template with all ~40 options.

### Command Reference

```bash
# Use default .env
./build.sh

# Use custom .env
./build.sh --env-file .env.production

# Preview build
./build.sh --dry-run

# Show help
./build.sh --help

# Override specific option
INCLUDE_DEMO=0 ./build.sh
```

---

## Additional Resources

- [QUICK-START.md](QUICK-START.md) - Quick start guide
- [README.md](README.md) - Complete documentation
- [.env.example](.env.example) - Template with all options

---

**Last Updated**: 2026-01-26
**Version**: 2.0
