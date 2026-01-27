# Pentaho Docker Build - Quick Start Guide

## Using .env Configuration (Recommended Method)

This is the **recommended approach** for building Pentaho Docker images. It uses a single `.env` file to configure everything - similar to the Docker Compose deployment.

### 1. Setup Configuration

```bash
cd docker-build

# Copy template to create your .env
cp .env.example .env

# Edit configuration
nano .env
```

### 2. Configure Key Settings

Edit `.env` and customize these key settings:

```bash
# Build Configuration
PENTAHO_VERSION=11.0.0.0-237
EDITION=ee                      # ee or ce
INCLUDE_DEMO=1                  # 1=yes, 0=no

# JVM Memory
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m

# License (Optional - for EE)
LICENSE_URL=https://company.com/licenses/pentaho-ee.lic

# What to do after build
LOAD_INTO_K3S=true             # Load into K3s automatically
PUSH_TO_REGISTRY=false         # Push to Docker registry
RUN_TESTS=true                 # Run validation tests
```

### 3. Build Image

```bash
# Make script executable (first time only)
chmod +x build.sh

# Build with .env configuration
./build.sh
```

The script will:
- ✅ Validate prerequisites
- ✅ Build Docker image
- ✅ Run tests
- ✅ Load into K3s (if enabled)
- ✅ Show next steps

### 4. Verify in K3s

```bash
# Check image is in K3s
sudo k3s ctr images ls | grep pentaho

# Deploy to K3s
cd ..
kubectl apply -f manifests/

# Watch deployment
kubectl get pods -n pentaho -w
```

---

## Build and Push to Registry

To rebuild and push to a Docker registry:

### 1. Configure Registry Settings

Edit `.env`:

```bash
# Enable registry push
PUSH_TO_REGISTRY=true

# Docker Hub
REGISTRY_URL=docker.io
REGISTRY_USERNAME=your-username
REGISTRY_PASSWORD=your-token
IMAGE_TAG=your-username/pentaho-server:11.0.0.0-237

# OR Private Harbor
REGISTRY_URL=harbor.company.com
REGISTRY_USERNAME=admin
REGISTRY_PASSWORD=Harbor12345
IMAGE_TAG=harbor.company.com/pentaho/pentaho-server:11.0.0.0-237

# Don't load into K3s (will pull from registry instead)
LOAD_INTO_K3S=false
```

### 2. Build and Push

```bash
./build.sh
```

### 3. Update K3s to Use Registry Image

Edit `../manifests/pentaho/deployment.yaml`:

```yaml
spec:
  template:
    spec:
      containers:
        - name: pentaho-server
          image: harbor.company.com/pentaho/pentaho-server:11.0.0.0-237
          imagePullPolicy: Always
```

For private registry, create secret:

```bash
kubectl create secret docker-registry pentaho-registry-secret \
    --docker-server=harbor.company.com \
    --docker-username=admin \
    --docker-password=Harbor12345 \
    -n pentaho
```

Add to deployment:

```yaml
spec:
  template:
    spec:
      imagePullSecrets:
        - name: pentaho-registry-secret
```

Deploy:

```bash
kubectl apply -f ../manifests/pentaho/deployment.yaml
kubectl rollout status deployment/pentaho-server -n pentaho
```

---

## Advanced Usage

### Use Different .env File

```bash
# Create production config
cp .env.example .env.production
nano .env.production

# Build with production config
./build.sh --env-file .env.production
```

### Dry Run (Preview Build)

```bash
# See what would be built without building
./build.sh --dry-run
```

### Override Specific Settings

```bash
# Override .env settings via environment variables
INCLUDE_DEMO=0 PUSH_TO_REGISTRY=true ./build.sh
```

---

## Common Workflows

### Development Workflow

```bash
# .env settings
INCLUDE_DEMO=1
LOAD_INTO_K3S=true
PUSH_TO_REGISTRY=false
RUN_TESTS=true

# Build
./build.sh

# Image automatically loaded into K3s
kubectl apply -f ../manifests/
```

### Production Workflow

```bash
# .env settings
INCLUDE_DEMO=0
PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=8192m
LICENSE_URL=https://licenses.company.com/pentaho-ee.lic
LOAD_INTO_K3S=false
PUSH_TO_REGISTRY=true
REGISTRY_URL=harbor.company.com

# Build and push
./build.sh

# Deploy from registry
kubectl set image deployment/pentaho-server \
    pentaho-server=harbor.company.com/pentaho/pentaho-server:11.0.0.0-237 \
    -n pentaho
```

### CI/CD Pipeline

```bash
# .env.ci
PENTAHO_VERSION=${CI_VERSION}
IMAGE_TAG=${REGISTRY_URL}/pentaho-server:${CI_COMMIT_TAG}
PUSH_TO_REGISTRY=true
LOAD_INTO_K3S=false
RUN_TESTS=true

# Build in pipeline
./build.sh --env-file .env.ci
```

---

## Troubleshooting

### Image Not Found in K3s

```bash
# Manually load
docker save pentaho/pentaho-server:11.0.0.0-237 | sudo k3s ctr images import -

# Or set in .env
LOAD_INTO_K3S=true
```

### Registry Push Failed

```bash
# Login manually first
docker login harbor.company.com

# Then build
./build.sh
```

### License Not Applied

```bash
# Check LICENSE_URL in .env
LICENSE_URL=https://company.com/licenses/pentaho-ee.lic

# Rebuild
./build.sh
```

### Error: "command not found" When Running build.sh

```bash
# Error: .env: line XX: -Djava.awt.headless=true: command not found
```

**Cause**: Values with spaces in `.env` must be quoted.

**Fix**: Add quotes around values with spaces:
```bash
# Wrong (causes error)
PENTAHO_DI_JAVA_OPTIONS=-Dfile.encoding=utf8 -Djava.awt.headless=true

# Correct (with quotes)
PENTAHO_DI_JAVA_OPTIONS="-Dfile.encoding=utf8 -Djava.awt.headless=true"
```

### Out of Memory During Build

```bash
# Increase Docker memory
# Docker Desktop: Settings → Resources → Memory → 8GB+

# Or build without demo
INCLUDE_DEMO=0 ./build.sh
```

---

## Complete Example

Here's a complete example from scratch:

```bash
# 1. Navigate to docker-build directory
cd docker-build

# 2. Place Pentaho package
cp ~/Downloads/pentaho-server-ee-11.0.0.0-237.zip stagedArtifacts/

# 3. Create configuration
cp .env.example .env

# 4. Edit configuration
nano .env
# Set: LOAD_INTO_K3S=true
# Set: LICENSE_URL=https://your-url (if you have one)

# 5. Build (one command!)
chmod +x build.sh
./build.sh

# 6. Deploy to K3s
cd ..
kubectl apply -f manifests/

# 7. Check deployment
kubectl get pods -n pentaho
kubectl logs -f deployment/pentaho-server -n pentaho

# 8. Access Pentaho
kubectl port-forward svc/pentaho-server 8080:8080 -n pentaho
# Open: http://localhost:8080/pentaho
# Login: admin / password
```

---

## Need Help?

- **Full Documentation**: See [README.md](README.md)
- **Configuration Guide**: See [ENV-CONFIGURATION.md](ENV-CONFIGURATION.md) - Complete guide to all .env options
- **Configuration Template**: See [.env.example](.env.example)
- **Troubleshooting**: See [README.md#troubleshooting](README.md#troubleshooting)

**Quick Command Reference:**
```bash
./build.sh                      # Build with .env
./build.sh --dry-run           # Preview build
./build.sh --env-file .env.prod # Use specific .env
./build.sh --help              # Show help
```
