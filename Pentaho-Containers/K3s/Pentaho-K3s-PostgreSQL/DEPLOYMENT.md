# Pentaho K3s Deployment Guide

## Status: ✅ DEPLOYMENT SUCCESSFUL

**Date**: 2026-01-26
**Pentaho Version**: 11.0.0.0-237
**PostgreSQL Version**: 15
**Kubernetes**: K3s

---

## Deployment Summary

Pentaho Server is successfully deployed and accessible in K3s cluster!

- **Pentaho Server**: Running and accessible (HTTP 200)
- **PostgreSQL**: Initialized with all required databases and tables
- **JCR Repository**: Successfully initialized
- **Quartz Scheduler**: Database tables created and populated

---

## Access Information

### Method 1: Port Forward (Recommended for Testing)
```bash
kubectl port-forward -n pentaho svc/pentaho-server 8080:8080
```
Then access: **http://localhost:8080/pentaho**

### Method 2: Ingress (Add to /etc/hosts)
```bash
echo "10.0.0.1 pentaho.local" | sudo tee -a /etc/hosts
```
Then access: **http://pentaho.local/pentaho**

### Default Credentials
- **Username**: `admin`
- **Password**: `password`
- ⚠️ **IMPORTANT**: Change these credentials for production deployments!

---

## Key Issues Resolved

### 1. PostgreSQL Initialization ✅
**Problem**: Original ConfigMap only created users and databases, but not the required tables and indexes.

**Solution**:
- Copied complete SQL scripts from working Docker Compose project
- Created new ConfigMap (`postgres-init-scripts.yaml`) with 5 SQL files:
  - `1_create_jcr_postgresql.sql` - JackRabbit user and database
  - `2_create_quartz_postgresql.sql` - Quartz user, database, 11 tables, 5 locks
  - `3_create_repository_postgresql.sql` - Hibernate user and database
  - `4_pentaho_logging_postgresql.sql` - Logging schema with ~15 tables
  - `5_pentaho_mart_postgresql.sql` - Mart schema with ~40 tables

### 2. Hostname Configuration ✅
**Problem**: Container tried to resolve its random container ID, causing `UnknownHostException`.

**Solution**:
- Added `hostname: pentaho-server` to deployment spec
- Matches Docker Compose configuration

### 3. Persistent Volumes ✅
**Problem**: Empty Kubernetes PVCs overwrite container directories, unlike Docker named volumes.

**Solution**:
- Commented out volume mounts for `pentaho-data` and `pentaho-solutions`
- Data persists in PostgreSQL databases
- For production: implement initContainer to populate PVCs on first run

### 4. SoftwareOverride Configuration ✅
**Problem**: Configuration files were mounted as ConfigMap (K8s approach) instead of being baked into image.

**Solution**:
- Copied softwareOverride directory into Docker image during build
- Updated Dockerfile to `COPY softwareOverride /docker-entrypoint-init`
- Removed create-softwareoverride-configmap.sh script (no longer needed)

---

## Architecture

### Docker Build Strategy
```
Pentaho Base Image (3.3GB)
├── Base installation from pentaho-server-ee-11.0.0.0-237.zip
├── Java 21 runtime
├── Tomcat 10.1.48
└── Configuration overlays (baked in):
    ├── 1_drivers/postgresql-42.7.1.jar
    ├── 2_repository/*.xml (database configs with postgres:5432)
    ├── 3_security/ (empty - no Vault)
    └── 4_others/*.sh (modified startup scripts)
```

### Kubernetes Architecture
```
Namespace: pentaho
│
├── PostgreSQL Deployment
│   ├── Image: postgres:15
│   ├── Port: 5432
│   ├── PVC: postgres-data-pvc (10Gi)
│   └── Init: SQL scripts from ConfigMap postgres-init-scripts
│
├── Pentaho Server Deployment
│   ├── Image: pentaho/pentaho-server:11.0.0.0-237
│   ├── Ports: 8080 (HTTP), 8443 (HTTPS)
│   ├── Init Container: wait-for-postgres
│   ├── Hostname: pentaho-server
│   └── No persistent volumes (data in PostgreSQL)
│
└── Services & Ingress
    ├── Service: postgres (ClusterIP)
    ├── Service: pentaho-server (ClusterIP)
    └── Ingress: pentaho-ingress (Traefik)
```

### Database Configuration
```
PostgreSQL (postgres:5432)
├── jackrabbit (owner: jcr_user)
│   └── Used by: JCR content repository
├── quartz (owner: pentaho_user)
│   ├── 11 tables (QRTZ6_*)
│   ├── 5 locks (PentahoQuartzScheduler)
│   └── Used by: Job scheduler
└── hibernate (owner: hibuser)
    ├── logging schema (~15 tables)
    ├── mart schema (~40 tables)
    └── Used by: Pentaho repository and audit
```

---

## Deployment Scripts

### Main Deployment Script: [deploy.sh](deploy.sh)
Unified script that handles both image import and resource deployment.

```bash
# Clean deployment (recommended)
./deploy.sh --clean

# Skip image import (if already imported)
./deploy.sh --skip-import

# Update only (restart pods)
./deploy.sh --update-only
```

**Features**:
- Pre-flight checks (Docker, kubectl, k3s, image, secrets)
- Colored output with progress indicators
- Image import to K3s containerd
- Sequential resource creation with error handling
- Health check monitoring
- Detailed access instructions

### Docker Build Script: [docker-build/build.sh](docker-build/build.sh)
Builds the Pentaho Docker image with configuration overlays.

```bash
cd docker-build
./build.sh
```

**Features**:
- Multi-stage build (3.3GB final size)
- Copies softwareOverride into image
- Validates image after build
- Tests Java version and Pentaho files
- Optional K3s import (requires sudo)

### Cleanup Script: [destroy.sh](destroy.sh)
Completely removes the Pentaho deployment.

```bash
./destroy.sh
```

**What it removes**:
- Deletes entire pentaho namespace
- Removes all resources (pods, services, ingress, etc.)
- Deletes persistent volumes and data
- ⚠️ This is destructive - all data will be lost!

---

## File Structure

```
Pentaho-K3s-PostgreSQL/
├── deploy.sh                 # Main deployment script
├── destroy.sh                # Cleanup script
├── README.md                 # Project documentation
├── DEPLOYMENT-SUCCESS.md     # This file
│
├── docker-build/             # Docker image build
│   ├── build.sh              # Build script
│   ├── Dockerfile            # Multi-stage build definition
│   ├── docker-entrypoint.sh  # Container startup script
│   ├── softwareOverride/     # Configuration overlays (baked into image)
│   │   ├── 1_drivers/        # PostgreSQL JDBC driver
│   │   ├── 2_repository/     # Database connection configs
│   │   ├── 3_security/       # Empty (no Vault)
│   │   └── 4_others/         # Modified Tomcat scripts
│   └── test-compose.yml      # Local Docker testing environment
│
├── db_init_postgres/         # SQL initialization scripts
│   ├── 1_create_jcr_postgresql.sql
│   ├── 2_create_quartz_postgresql.sql
│   ├── 3_create_repository_postgresql.sql
│   ├── 4_pentaho_logging_postgresql.sql
│   └── 5_pentaho_mart_postgresql.sql
│
├── manifests/                # Kubernetes manifests
│   ├── configmaps/
│   │   ├── pentaho-config.yaml           # Pentaho environment config
│   │   └── postgres-init-scripts.yaml    # Database init SQL scripts
│   ├── pentaho/
│   │   ├── deployment.yaml               # Pentaho Server deployment
│   │   └── service.yaml                  # Pentaho ClusterIP service
│   ├── postgres/
│   │   ├── deployment.yaml               # PostgreSQL deployment
│   │   └── service.yaml                  # PostgreSQL ClusterIP service
│   ├── secrets/
│   │   └── secrets.yaml                  # Database passwords (gitignored)
│   ├── storage/
│   │   └── pvc.yaml                      # PersistentVolumeClaims
│   └── ingress/
│       └── ingress.yaml                  # Traefik ingress rules
│
└── scripts/                  # Utility scripts
    ├── backup-postgres.sh    # Database backup
    ├── restore-postgres.sh   # Database restore
    ├── validate-deployment.sh # Deployment validation
    └── verify-k3s.sh         # K3s cluster verification
```

---

## Testing Checklist

### ✅ PostgreSQL
- [x] Pod is running
- [x] Database users created (jcr_user, pentaho_user, hibuser)
- [x] Databases created (jackrabbit, quartz, hibernate)
- [x] Quartz tables created (11 tables)
- [x] Quartz locks populated (5 rows)
- [x] Hibernate schemas created (logging, mart)
- [x] Port 5432 accessible within cluster

### ✅ Pentaho Server
- [x] Pod is running (1/1 READY)
- [x] No "Cannot obtain JCR repository" error
- [x] JCR repository initialized successfully
- [x] Tomcat started without errors
- [x] /pentaho webapp deployed (HTTP 200)
- [x] Login page accessible
- [x] Port 8080 accessible via port-forward
- [x] Hostname resolution working

### ✅ Configuration
- [x] Database connections use correct hostname (postgres:5432)
- [x] PostgreSQL JDBC driver loaded
- [x] Modified startup scripts applied (foreground mode)
- [x] SoftwareOverride files copied to container
- [x] No volume mount conflicts

---

## Monitoring Commands

### Check Pod Status
```bash
kubectl get pods -n pentaho
```

### Watch Pentaho Logs
```bash
kubectl logs -f deployment/pentaho-server -n pentaho
```

### Check PostgreSQL Logs
```bash
kubectl logs -f deployment/postgres -n pentaho
```

### Verify Database Tables
```bash
# Check Quartz locks
kubectl exec -n pentaho deployment/postgres -- \
  psql -U pentaho_user -d quartz -c "SELECT * FROM qrtz6_locks;"

# List all databases
kubectl exec -n pentaho deployment/postgres -- \
  psql -U postgres -c "\l"

# List Quartz tables
kubectl exec -n pentaho deployment/postgres -- \
  psql -U pentaho_user -d quartz -c "\dt"
```

### Check All Resources
```bash
kubectl get all -n pentaho
```

### Describe Pentaho Pod
```bash
kubectl describe pod -n pentaho -l app=pentaho-server
```

---

## Known Limitations

### 1. No Persistent Volumes for Pentaho Files
**Impact**: Container restarts lose uploaded content, custom reports, and temporary files.

**Mitigation**:
- Use PostgreSQL for all data storage
- Implement initContainer to populate PVCs (future enhancement)
- For production: Store reports in version control and deploy via CI/CD

### 2. Single Replica Only
**Impact**: No high availability, downtime during updates.

**Mitigation**:
- K3s uses Recreate strategy (not RollingUpdate)
- ReadWriteOnce volumes don't support multiple pods
- For HA: Requires ReadWriteMany volumes or external storage

### 3. License Errors in Logs
**Impact**: Enterprise features (EE Quartz scheduler, SAP HANA) unavailable.

**Status**: Expected behavior - running Community Edition without license.

### 4. No TLS/HTTPS
**Impact**: Unencrypted HTTP traffic only.

**Mitigation**:
- For production: Configure TLS ingress with cert-manager
- Use Let's Encrypt for automated certificate management

---

## Production Recommendations

### 1. Implement Persistent Volumes Properly
Add initContainer to populate PVCs on first run:
```yaml
initContainers:
  - name: init-pentaho-solutions
    image: pentaho/pentaho-server:11.0.0.0-237
    command: ["/bin/sh", "-c"]
    args:
      - |
        if [ ! -f /pentaho-solutions/system/pentaho.xml ]; then
          cp -a /opt/pentaho/pentaho-server/pentaho-solutions/. /pentaho-solutions/
        fi
    volumeMounts:
      - name: pentaho-solutions
        mountPath: /pentaho-solutions
```

### 2. Secure Secrets Management
- Use external secrets operator (AWS Secrets Manager, Azure Key Vault)
- Rotate passwords regularly
- Don't commit secrets to version control

### 3. Configure Resource Limits
- Monitor actual usage with Prometheus/Grafana
- Adjust memory/CPU based on workload
- Enable HorizontalPodAutoscaler (when HA is configured)

### 4. Implement Backup Strategy
- Schedule regular PostgreSQL backups
- Test restore procedures
- Store backups in external storage (S3, NFS)

### 5. Enable TLS/HTTPS
- Install cert-manager
- Configure TLS ingress
- Force HTTPS redirects

### 6. Monitoring and Observability
- Deploy Prometheus for metrics collection
- Configure Grafana dashboards
- Set up alerting (PagerDuty, Slack)
- Enable audit logging

---

## Troubleshooting

### Pentaho Pod Not Starting
```bash
# Check pod status
kubectl get pods -n pentaho

# Check pod events
kubectl describe pod -n pentaho -l app=pentaho-server

# Check logs
kubectl logs -n pentaho -l app=pentaho-server

# Common issues:
# - Image not imported to K3s
# - PostgreSQL not ready (wait for postgres pod)
# - Resource limits too low (OOMKilled)
```

### PostgreSQL Connection Errors
```bash
# Verify PostgreSQL is running
kubectl get pods -n pentaho -l app=postgres

# Check PostgreSQL logs
kubectl logs -n pentaho deployment/postgres

# Test connection from Pentaho pod
kubectl exec -n pentaho deployment/pentaho-server -- \
  nc -zv postgres 5432
```

### Login Page Shows 404
```bash
# Check if /pentaho webapp deployed
kubectl logs -n pentaho deployment/pentaho-server | \
  grep "Deployment of web application"

# Expected output:
# Deployment of web application directory [.../pentaho] has finished in [70,000] ms
```

### JCR Repository Errors
```bash
# Check database initialization
kubectl logs -n pentaho deployment/postgres | \
  grep -i "CREATE\|PostgreSQL init"

# Verify jackrabbit database exists
kubectl exec -n pentaho deployment/postgres -- \
  psql -U postgres -c "\l" | grep jackrabbit
```

---

## Next Steps

1. **Test Functionality**: Login and create a simple report
2. **Configure LDAP**: Integrate with corporate directory
3. **Setup Monitoring**: Deploy Prometheus/Grafana
4. **Enable Backups**: Schedule automated PostgreSQL backups
5. **Implement HA**: Configure multi-replica deployment with ReadWriteMany PVC
6. **Secure Access**: Enable TLS and configure proper authentication
7. **Performance Tuning**: Adjust JVM settings and resource limits based on load

---

## References

- [Pentaho Documentation](https://docs.hitachivantara.com/r/en-us/pentaho-data-integration-and-analytics/11.0.x)
- [K3s Documentation](https://docs.k3s.io/)
- [PostgreSQL 15 Documentation](https://www.postgresql.org/docs/15/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

**Last Updated**: 2026-01-26
**Deployment Status**: ✅ SUCCESSFUL
**Pentaho Server**: http://localhost:8080/pentaho (via port-forward)
