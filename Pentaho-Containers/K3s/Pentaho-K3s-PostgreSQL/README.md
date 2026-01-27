# Pentaho Server 11 on K3s with PostgreSQL

✅ **Production-ready Kubernetes deployment - Tested and Working**

Deploy Pentaho Server 11.0.0.0-237 with PostgreSQL 15 on K3s (lightweight Kubernetes).

---

## Quick Start

### Prerequisites
- Ubuntu 24.04 (or similar Linux)
- 8GB RAM minimum (16GB recommended)
- Docker installed
- K3s installed (see [K3s Installation](#k3s-installation) below)

### Deploy in 3 Steps

```bash
# 1. Build the Pentaho Docker image
cd docker-build
./build.sh

# 2. Import image to K3s (password: password)
docker save pentaho/pentaho-server:11.0.0.0-237 -o /tmp/pentaho.tar
echo "password" | sudo -S k3s ctr images import /tmp/pentaho.tar

# 3. Deploy to K3s
cd ..
./deploy.sh --skip-import
```

### Access Pentaho

```bash
# Port forward to access locally
kubectl port-forward -n pentaho svc/pentaho-server 8080:8080
```

Open: **http://localhost:8080/pentaho**

**Default Login**: `admin` / `password`

---

## What's Deployed

### Services
- **Pentaho Server 11.0.0.0-237** - Business analytics platform
- **PostgreSQL 15** - Three databases (jackrabbit, quartz, hibernate)
- **Traefik Ingress** - HTTP routing (included with K3s)

### Storage
- PostgreSQL: 10GB persistent volume
- Pentaho data persists in PostgreSQL (no file volumes to avoid conflicts)

### Namespace
All resources deploy to the `pentaho` namespace.

---

## K3s Installation

If you don't have K3s installed:

```bash
# Install K3s (single-node cluster)
curl -sfL https://get.k3s.io | sh -

# Verify installation
sudo k3s kubectl get nodes

# Allow kubectl without sudo (optional)
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
export KUBECONFIG=~/.kube/config
```

**See [K3s-INSTALLATION.md](K3s-INSTALLATION.md) for detailed instructions and multi-node setup.**

---

## Deployment Scripts

### Quick Commands with Makefile (New!) ⭐

```bash
make help           # Show all available commands
make full-deploy    # Build, import, and deploy (complete workflow)
make health         # Run health check
make status         # Show deployment status
make logs           # View Pentaho logs
make port-forward   # Access Pentaho at localhost:8080
make destroy        # Remove deployment
```

**See all commands**: Run `make help`

### Main Deployment: `deploy.sh`

```bash
# Fresh deployment (recommended)
./deploy.sh --skip-import

# Clean old images first
./deploy.sh --clean

# Update existing deployment
./deploy.sh --update-only
```

**Features:**
- Pre-flight checks (Docker, kubectl, K3s, secrets)
- Sequential resource creation with error handling
- Health check monitoring
- Colored progress output

### Docker Build: `docker-build/build.sh`

```bash
cd docker-build
./build.sh
# Or: make build
```

**What it does:**
- Builds Pentaho image from official installer
- Copies PostgreSQL configuration overlays
- Tests the built image
- Size: ~3.3GB

### Cleanup: `destroy.sh`

```bash
./destroy.sh
# Or: make destroy
```

⚠️ **WARNING**: Deletes entire pentaho namespace and all data!

---

## Architecture

### Kubernetes Resources
```
pentaho namespace
├── PostgreSQL Deployment
│   ├── Image: postgres:15
│   ├── Port: 5432
│   ├── Volume: 10GB PVC
│   └── Init: SQL scripts from ConfigMap
│
├── Pentaho Deployment
│   ├── Image: pentaho/pentaho-server:11.0.0.0-237
│   ├── Ports: 8080 (HTTP), 8443 (HTTPS)
│   ├── Init Container: wait-for-postgres
│   └── No persistent volumes (avoids K8s/Docker volume differences)
│
└── Services & Ingress
    ├── postgres (ClusterIP)
    ├── pentaho-server (ClusterIP)
    └── pentaho-ingress (Traefik)
```

### Database Schema
```
PostgreSQL (postgres:5432)
├── jackrabbit (owner: jcr_user)
│   └── JCR content repository
├── quartz (owner: pentaho_user)
│   ├── 11 tables (QRTZ6_*)
│   └── 5 scheduler locks
└── hibernate (owner: hibuser)
    ├── logging schema (~15 tables)
    └── mart schema (~40 tables)
```

---

## Configuration

### Database Passwords

Stored in `manifests/secrets/secrets.yaml` (gitignored):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
  namespace: pentaho
type: Opaque
stringData:
  postgres-password: "password"    # PostgreSQL admin
  jcr-password: "password"         # JCR repository
  quartz-password: "password"      # Quartz scheduler
  hibernate-password: "password"   # Hibernate repository
```

**Production**: Change all passwords before deploying!

### Environment Variables

Configured in `manifests/configmaps/pentaho-config.yaml`:
- `PENTAHO_MIN_MEMORY`: 2048m (JVM min heap)
- `PENTAHO_MAX_MEMORY`: 6144m (JVM max heap)
- `DB_TYPE`: postgres

### Database Connection

All connections configured in the Docker image at build time:
- **File**: `docker-build/softwareOverride/2_repository/tomcat/webapps/pentaho/META-INF/context.xml`
- **Hostname**: `postgres:5432`
- **Driver**: PostgreSQL JDBC 42.7.1 (included in image)

---

## Monitoring

### Health Check (New!) ⭐

```bash
# Quick health check
make health
# Or: ./scripts/health-check.sh
```

**Checks:**
- Pod status (running and ready)
- Service availability
- Database connectivity
- Pentaho web application (HTTP 200)
- Resource usage

### Resource Monitoring (New!) ⭐

```bash
# Monitor resources
make monitor
# Or: ./scripts/monitor-resources.sh
```

**Shows:**
- Pod CPU/Memory usage
- Node resource usage
- PVC storage status
- Resource limits and requests
- Container restart counts

### PostgreSQL Monitoring (New!) ⭐

```bash
# Monitor PostgreSQL
make monitor-postgres
# Or: ./scripts/monitor-postgres.sh
```

**Shows:**
- Database sizes
- Active connections
- Table sizes
- Quartz scheduler status
- Cache hit ratios
- Query performance

### Check Status
```bash
# All resources
kubectl get all -n pentaho
# Or: make status

# Just pods
kubectl get pods -n pentaho
# Or: make quick-status

# Watch pod startup
kubectl get pods -n pentaho -w
```

### View Logs
```bash
# Pentaho logs
kubectl logs -f deployment/pentaho-server -n pentaho
# Or: make logs

# PostgreSQL logs
kubectl logs -f deployment/postgres -n pentaho
# Or: make logs-postgres

# Last 100 lines
kubectl logs deployment/pentaho-server -n pentaho --tail=100
```

### Database Access
```bash
# Connect to PostgreSQL shell
make db-shell
# Or: kubectl exec -it -n pentaho deployment/postgres -- psql -U postgres

# List databases
kubectl exec -n pentaho deployment/postgres -- \
  psql -U postgres -c "\l"

# Check Quartz locks
kubectl exec -n pentaho deployment/postgres -- \
  psql -U pentaho_user -d quartz -c "SELECT * FROM qrtz6_locks;"
```

---

## Troubleshooting

### Pentaho Pod Not Starting

```bash
# Check pod status
kubectl describe pod -n pentaho -l app=pentaho-server

# Check events
kubectl get events -n pentaho --sort-by='.lastTimestamp'

# Common issues:
# - Image not imported: docker save + sudo k3s ctr images import
# - PostgreSQL not ready: wait for postgres pod to be 1/1 Running
# - Out of memory: increase limits in deployment.yaml
```

### PostgreSQL Connection Errors

```bash
# Verify PostgreSQL is running
kubectl get pods -n pentaho -l app=postgres

# Test connection from Pentaho pod
kubectl exec -n pentaho deployment/pentaho-server -- \
  nc -zv postgres 5432
```

### Login Page Shows 404

```bash
# Check if /pentaho webapp deployed
kubectl logs -n pentaho deployment/pentaho-server | \
  grep "Deployment of web application"

# Should see: "...directory [.../pentaho] has finished in [~70000] ms"
```

### Port Forward Not Working

```bash
# Kill existing port-forwards
killall kubectl

# Check service exists
kubectl get svc -n pentaho pentaho-server

# Try different port
kubectl port-forward -n pentaho svc/pentaho-server 9080:8080
# Access: http://localhost:9080/pentaho
```

---

## File Structure

```
Pentaho-K3s-PostgreSQL/
├── deploy.sh                    # Main deployment script
├── destroy.sh                   # Cleanup script
├── README.md                    # This file
├── DEPLOYMENT.md                # Detailed deployment guide
├── K3s-INSTALLATION.md          # K3s setup instructions
│
├── docker-build/                # Docker image build
│   ├── build.sh                 # Build script
│   ├── Dockerfile               # Image definition
│   ├── docker-entrypoint.sh     # Container startup
│   ├── softwareOverride/        # Config overlays (baked into image)
│   │   ├── 1_drivers/           # PostgreSQL JDBC driver
│   │   ├── 2_repository/        # Database configs
│   │   ├── 3_security/          # (empty - no Vault)
│   │   └── 4_others/            # Modified Tomcat scripts
│   └── test-compose.yml         # Local Docker testing
│
├── db_init_postgres/            # PostgreSQL init SQL scripts
│   ├── 1_create_jcr_postgresql.sql
│   ├── 2_create_quartz_postgresql.sql
│   ├── 3_create_repository_postgresql.sql
│   ├── 4_pentaho_logging_postgresql.sql
│   └── 5_pentaho_mart_postgresql.sql
│
├── manifests/                   # Kubernetes manifests
│   ├── configmaps/
│   │   ├── pentaho-config.yaml
│   │   └── postgres-init-scripts.yaml
│   ├── pentaho/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── postgres/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── secrets/
│   │   └── secrets.yaml          # (gitignored)
│   ├── storage/
│   │   └── pvc.yaml
│   └── ingress/
│       └── ingress.yaml
│
└── scripts/                     # Utility scripts
    ├── backup-postgres.sh       # Database backup
    ├── restore-postgres.sh      # Database restore
    ├── validate-deployment.sh   # Deployment checks
    └── verify-k3s.sh            # K3s verification
```

---

## Production Recommendations

### 1. Security
- [ ] Change all default passwords in `secrets.yaml`
- [ ] Enable TLS/HTTPS with cert-manager
- [ ] Configure LDAP/Active Directory authentication
- [ ] Restrict network policies

### 2. Storage
- [ ] Implement proper persistent volumes with initContainer
- [ ] Schedule regular PostgreSQL backups
- [ ] Test backup restore procedures
- [ ] Use external storage (NFS, Ceph, or cloud)

### 3. Monitoring
- [ ] Deploy Prometheus for metrics
- [ ] Set up Grafana dashboards
- [ ] Configure alerting (PagerDuty, Slack)
- [ ] Enable audit logging

### 4. High Availability
- [ ] Multi-node K3s cluster (see `WORKSHOP-MULTI-NODE.md`)
- [ ] PostgreSQL replication
- [ ] Multiple Pentaho replicas with session affinity
- [ ] External load balancer

### 5. Performance
- [ ] Tune JVM heap sizes based on workload
- [ ] Adjust PostgreSQL shared_buffers
- [ ] Monitor resource usage and adjust limits
- [ ] Enable HorizontalPodAutoscaler

---

## Advanced Topics

### Local Testing with Docker Compose

Before deploying to K3s, test the image locally:

```bash
cd docker-build
docker compose -f test-compose.yml up
```

Access: http://localhost:8080/pentaho

### Custom Configuration

To modify Pentaho configuration:

1. Edit files in `docker-build/softwareOverride/`
2. Rebuild image: `cd docker-build && ./build.sh`
3. Re-import to K3s
4. Redeploy: `./deploy.sh --update-only`

### Database Backups

```bash
# Backup all databases
./scripts/backup-postgres.sh

# Restore from backup
./scripts/restore-postgres.sh backup-2026-01-26.sql
```

### Multi-Node Cluster

For high availability across multiple nodes:

**See [WORKSHOP-MULTI-NODE.md](WORKSHOP-MULTI-NODE.md) for complete guide.**

---

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide with troubleshooting
- **[K3s-INSTALLATION.md](K3s-INSTALLATION.md)** - K3s setup and configuration
- **[WORKSHOP-SINGLE-NODE.md](WORKSHOP-SINGLE-NODE.md)** - Hands-on single-node workshop
- **[WORKSHOP-MULTI-NODE.md](WORKSHOP-MULTI-NODE.md)** - Multi-node HA workshop

---

## Support & Resources

- [Pentaho Documentation](https://docs.hitachivantara.com/r/en-us/pentaho-data-integration-and-analytics/11.0.x)
- [K3s Documentation](https://docs.k3s.io/)
- [PostgreSQL 15 Docs](https://www.postgresql.org/docs/15/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

## License

This deployment configuration is provided as-is for deploying Pentaho Server. Pentaho Server itself requires appropriate licensing from Hitachi Vantara.

---

**Project Status**: ✅ Production Ready
**Last Updated**: 2026-01-26
**Tested On**: Ubuntu 24.04, K3s v1.28+
