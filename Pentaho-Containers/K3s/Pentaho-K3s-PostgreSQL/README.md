# Pentaho Server 11 K3s Deployment (PostgreSQL)

Complete Kubernetes deployment for Pentaho Server 11.0.0.0-237 with PostgreSQL 15 repository on K3s (lightweight Kubernetes) running on Ubuntu 24.04.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [K3s Installation](#k3s-installation)
- [Quick Start](#quick-start)
- [Manual Deployment](#manual-deployment)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Accessing Services](#accessing-services)
- [Database Management](#database-management)
- [Troubleshooting](#troubleshooting)
- [Production Hardening](#production-hardening)
- [Backup and Recovery](#backup-and-recovery)
- [Project Structure](#project-structure)

## Overview

This project provides a production-ready K3s (Kubernetes) deployment for:

- **Pentaho Server 11.0.0.0-237** (Enterprise Edition)
- **PostgreSQL 15** with Pentaho repository databases
- **K3s** lightweight Kubernetes on Ubuntu 24.04

### Key Features

- Lightweight Kubernetes (K3s) - single binary, low resource usage
- Kubernetes-native deployment with Deployments, Services, ConfigMaps
- Persistent storage using K3s local-path provisioner
- Ingress controller (Traefik) included with K3s
- Secret management via Kubernetes Secrets
- Health checks and readiness probes
- Horizontal scaling capability
- Easy backup and restore

### K3s vs Docker Compose

| Aspect | Docker Compose | K3s |
|--------|----------------|-----|
| Orchestration | Single host | Multi-node capable |
| Scaling | Manual | Horizontal Pod Autoscaler |
| Service Discovery | Container names | DNS-based (CoreDNS) |
| Load Balancing | Manual/external | Built-in (Traefik) |
| Storage | Docker volumes | PersistentVolumeClaims |
| Secrets | Docker secrets/files | Kubernetes Secrets |
| Health Checks | HEALTHCHECK | Liveness/Readiness Probes |
| Rolling Updates | Manual | Built-in |

## Prerequisites

### System Requirements

- **OS**: Ubuntu 24.04 LTS (also compatible with Ubuntu 22.04)
- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 20GB+ available space
- **Network**: Static IP or DHCP reservation recommended

### Software Requirements

1. **Ubuntu 24.04** with sudo access
2. **curl** (usually pre-installed)
3. **Pentaho Package**: `pentaho-server-ee-11.0.0.0-237.zip` from Hitachi Vantara

## K3s Installation

For detailed K3s installation instructions, see [K3s-INSTALLATION.md](K3s-INSTALLATION.md).

### Quick K3s Install

```bash
# Install K3s (single-node cluster)
curl -sfL https://get.k3s.io | sh -

# Verify installation
sudo k3s kubectl get nodes

# Set up kubectl for non-root user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Verify kubectl works
kubectl get nodes
```

## Quick Start

### 1. Clone/Copy Project

```bash
cd /path/to/Pentaho-Containers/K3s/Pentaho-K3s-PostgreSQL
```

### 2. Prepare Pentaho Container Image

You need to build and import the Pentaho container image into K3s:

```bash
# Option A: Build locally with Docker and import to K3s
# (requires Docker installed alongside K3s)
cd ../On-Prem/Pentaho-Server-PostgreSQL
docker build -t pentaho/pentaho-server:11.0.0.0-237 ./docker
docker save pentaho/pentaho-server:11.0.0.0-237 | sudo k3s ctr images import -

# Option B: Use a container registry
# Push to your registry and update manifests/pentaho/deployment.yaml
```

### 3. Configure Secrets

```bash
# Edit secrets with your passwords
cp manifests/secrets/secrets.yaml.template manifests/secrets/secrets.yaml
nano manifests/secrets/secrets.yaml

# Or generate base64-encoded passwords:
echo -n 'your-password' | base64
```

### 4. Deploy

```bash
# Run the deployment script
chmod +x deploy.sh
./deploy.sh
```

### 5. Access Pentaho

```bash
# Get the service URL
kubectl get ingress -n pentaho

# Or use port-forward for testing
kubectl port-forward svc/pentaho-server 8080:8080 -n pentaho
```

Access Pentaho at: http://localhost:8080/pentaho
- Username: `admin`
- Password: `password`

## Manual Deployment

### Step-by-Step Deployment

```bash
# 1. Create namespace
kubectl apply -f manifests/namespace.yaml

# 2. Create secrets
kubectl apply -f manifests/secrets/

# 3. Create ConfigMaps
kubectl apply -f manifests/configmaps/

# 4. Create PersistentVolumeClaims
kubectl apply -f manifests/storage/

# 5. Deploy PostgreSQL
kubectl apply -f manifests/postgres/

# 6. Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n pentaho --timeout=120s

# 7. Deploy Pentaho Server
kubectl apply -f manifests/pentaho/

# 8. Create Ingress (optional)
kubectl apply -f manifests/ingress/
```

### Verify Deployment

```bash
# Check all resources
kubectl get all -n pentaho

# Check pod status
kubectl get pods -n pentaho -w

# View logs
kubectl logs -f deployment/pentaho-server -n pentaho
```

## Configuration

### Environment Variables

Edit `manifests/configmaps/pentaho-config.yaml`:

```yaml
data:
  PENTAHO_MIN_MEMORY: "2048m"
  PENTAHO_MAX_MEMORY: "4096m"
  DB_HOST: "postgres"
  DB_PORT: "5432"
```

### Database Credentials

Edit `manifests/secrets/secrets.yaml`:

```yaml
data:
  postgres-password: <base64-encoded-password>
  pentaho-db-password: <base64-encoded-password>
```

Generate base64 values:
```bash
echo -n 'your-secure-password' | base64
```

### Persistent Storage

Default storage class: `local-path` (K3s default)

To use different storage:
```yaml
spec:
  storageClassName: your-storage-class
```

## Architecture

### Kubernetes Resources

```
┌─────────────────────────────────────────────────────────────┐
│                    Namespace: pentaho                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────┐    ┌─────────────────────┐         │
│  │  Ingress (Traefik)  │    │    ConfigMaps       │         │
│  │  - pentaho.local    │    │  - pentaho-config   │         │
│  └──────────┬──────────┘    │  - postgres-init    │         │
│             │               └─────────────────────┘         │
│             ▼                                                │
│  ┌─────────────────────┐    ┌─────────────────────┐         │
│  │  Service            │    │    Secrets          │         │
│  │  - pentaho-server   │    │  - pentaho-secrets  │         │
│  │  - postgres         │    │  - postgres-secrets │         │
│  └──────────┬──────────┘    └─────────────────────┘         │
│             │                                                │
│             ▼                                                │
│  ┌─────────────────────────────────────────────┐            │
│  │              Deployments                     │            │
│  │  ┌─────────────────┐  ┌─────────────────┐   │            │
│  │  │ pentaho-server  │  │    postgres     │   │            │
│  │  │ (1 replica)     │  │  (1 replica)    │   │            │
│  │  │                 │  │                 │   │            │
│  │  │ Port: 8080      │  │ Port: 5432      │   │            │
│  │  └────────┬────────┘  └────────┬────────┘   │            │
│  └───────────┼────────────────────┼────────────┘            │
│              │                    │                          │
│              ▼                    ▼                          │
│  ┌─────────────────────────────────────────────┐            │
│  │         PersistentVolumeClaims              │            │
│  │  - pentaho-data-pvc (10Gi)                  │            │
│  │  - pentaho-solutions-pvc (5Gi)              │            │
│  │  - postgres-data-pvc (10Gi)                 │            │
│  └─────────────────────────────────────────────┘            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Network Flow

```
External Request
       │
       ▼
┌──────────────┐
│   Traefik    │  K3s Ingress Controller (port 80/443)
│   Ingress    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Service    │  pentaho-server:8080
│  ClusterIP   │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│   Pentaho    │────▶│  PostgreSQL  │
│    Pod       │     │     Pod      │
└──────────────┘     └──────────────┘
                     postgres:5432
```

### Data Persistence

| PVC | Size | Purpose |
|-----|------|---------|
| postgres-data-pvc | 10Gi | PostgreSQL databases |
| pentaho-data-pvc | 10Gi | Pentaho data files |
| pentaho-solutions-pvc | 5Gi | Pentaho solutions repository |

## Accessing Services

### Via Ingress (Production)

1. Configure DNS or `/etc/hosts`:
   ```bash
   echo "$(hostname -I | awk '{print $1}') pentaho.local" | sudo tee -a /etc/hosts
   ```

2. Access: http://pentaho.local/pentaho

### Via Port Forward (Development)

```bash
# Pentaho Server
kubectl port-forward svc/pentaho-server 8080:8080 -n pentaho

# PostgreSQL (for database tools)
kubectl port-forward svc/postgres 5432:5432 -n pentaho
```

### Via NodePort

Edit `manifests/pentaho/service.yaml` to use NodePort:

```yaml
spec:
  type: NodePort
  ports:
    - port: 8080
      nodePort: 30080
```

Access: http://<node-ip>:30080/pentaho

## Database Management

### Access PostgreSQL

```bash
# Get a shell in the postgres pod
kubectl exec -it deployment/postgres -n pentaho -- psql -U postgres

# Run SQL commands
\l                    # List databases
\c jackrabbit         # Connect to database
\dt                   # List tables
\q                    # Quit
```

### Backup Database

```bash
# Create backup
kubectl exec deployment/postgres -n pentaho -- \
  pg_dumpall -U postgres > backup-$(date +%Y%m%d).sql

# Or use the backup script
./scripts/backup-postgres.sh
```

### Restore Database

```bash
# Restore from backup
cat backup-20260119.sql | kubectl exec -i deployment/postgres -n pentaho -- \
  psql -U postgres
```

## Troubleshooting

### Check Pod Status

```bash
# List all pods
kubectl get pods -n pentaho

# Describe a pod (shows events and issues)
kubectl describe pod <pod-name> -n pentaho

# Check pod logs
kubectl logs <pod-name> -n pentaho
kubectl logs -f deployment/pentaho-server -n pentaho
```

### Common Issues

#### Pod Stuck in Pending

```bash
# Check events
kubectl describe pod <pod-name> -n pentaho

# Common causes:
# - Insufficient resources: Check node capacity
# - PVC not bound: Check storage class
kubectl get pvc -n pentaho
```

#### Pod CrashLoopBackOff

```bash
# Check logs
kubectl logs <pod-name> -n pentaho --previous

# Common causes:
# - Database not ready
# - Incorrect credentials
# - Missing configuration
```

#### Cannot Connect to Database

```bash
# Verify postgres is running
kubectl get pods -l app=postgres -n pentaho

# Test connectivity from pentaho pod
kubectl exec deployment/pentaho-server -n pentaho -- \
  nc -zv postgres 5432
```

#### Ingress Not Working

```bash
# Check ingress status
kubectl get ingress -n pentaho
kubectl describe ingress pentaho-ingress -n pentaho

# Check Traefik logs
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

### Reset Deployment

```bash
# Delete and recreate everything
kubectl delete namespace pentaho
./deploy.sh
```

## Production Hardening

### Security Checklist

- [ ] Change all default passwords
- [ ] Enable TLS/SSL for Ingress
- [ ] Configure Network Policies
- [ ] Set resource limits on all pods
- [ ] Enable RBAC
- [ ] Use external secrets management (Vault, Sealed Secrets)
- [ ] Configure pod security policies
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure log aggregation

### Enable TLS

```yaml
# In manifests/ingress/ingress.yaml
spec:
  tls:
    - hosts:
        - pentaho.local
      secretName: pentaho-tls
```

Create TLS secret:
```bash
kubectl create secret tls pentaho-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n pentaho
```

### Resource Limits

Already configured in deployment manifests:

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1"
  limits:
    memory: "6Gi"
    cpu: "4"
```

## Backup and Recovery

### Automated Backups

Set up a CronJob for automated backups:

```bash
kubectl apply -f manifests/backup/backup-cronjob.yaml
```

### Disaster Recovery

1. Back up all manifests and configuration
2. Back up PostgreSQL data regularly
3. Back up PersistentVolume data
4. Document recovery procedures

### Full Cluster Recovery

```bash
# 1. Install K3s on new node
curl -sfL https://get.k3s.io | sh -

# 2. Apply manifests
./deploy.sh

# 3. Restore database
./scripts/restore-postgres.sh backup-file.sql
```

## Project Structure

```
Pentaho-K3s-PostgreSQL/
├── README.md                    # This documentation
├── K3s-INSTALLATION.md          # K3s installation guide
├── deploy.sh                    # Automated deployment script
├── destroy.sh                   # Cleanup script
│
├── manifests/
│   ├── namespace.yaml           # Kubernetes namespace
│   │
│   ├── secrets/
│   │   ├── secrets.yaml.template
│   │   └── secrets.yaml         # Database credentials (gitignored)
│   │
│   ├── configmaps/
│   │   ├── pentaho-config.yaml  # Pentaho environment config
│   │   └── postgres-init.yaml   # Database initialization SQL
│   │
│   ├── storage/
│   │   └── pvc.yaml             # PersistentVolumeClaims
│   │
│   ├── postgres/
│   │   ├── deployment.yaml      # PostgreSQL Deployment
│   │   └── service.yaml         # PostgreSQL Service
│   │
│   ├── pentaho/
│   │   ├── deployment.yaml      # Pentaho Server Deployment
│   │   └── service.yaml         # Pentaho Server Service
│   │
│   └── ingress/
│       └── ingress.yaml         # Traefik Ingress
│
├── scripts/
│   ├── backup-postgres.sh       # Database backup
│   ├── restore-postgres.sh      # Database restore
│   └── validate-deployment.sh   # Deployment validation
│
└── config/
    └── softwareOverride/        # Pentaho configuration overrides
        └── (same structure as On-Prem version)
```

## Comparison with On-Prem Docker Deployment

| Feature | Docker Compose (On-Prem) | K3s (This Project) |
|---------|-------------------------|---------------------|
| Deployment | `docker compose up` | `kubectl apply` |
| Scaling | Manual | `kubectl scale` |
| Updates | Rebuild container | Rolling update |
| Networking | Docker network | Kubernetes Services |
| Storage | Docker volumes | PVCs |
| Secrets | Docker secrets | K8s Secrets |
| Ingress | Manual/Nginx | Traefik (built-in) |
| Monitoring | Manual | Prometheus-ready |

---

**Project Version**: 1.0.0
**Pentaho Version**: 11.0.0.0-237
**PostgreSQL Version**: 15
**K3s Version**: Latest stable
**Last Updated**: 2026-01-19
