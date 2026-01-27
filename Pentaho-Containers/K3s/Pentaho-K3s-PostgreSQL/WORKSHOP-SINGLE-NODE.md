# Workshop: Deploying Pentaho Server on Single-Node K3s

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Workshop Overview](#workshop-overview)
4. [Part 1: Environment Setup](#part-1-environment-setup)
5. [Part 2: K3s Installation](#part-2-k3s-installation)
6. [Part 3: Understanding the Architecture](#part-3-understanding-the-architecture)
7. [Part 4: Deploying Pentaho](#part-4-deploying-pentaho)
8. [Part 5: Verification and Testing](#part-5-verification-and-testing)
9. [Part 6: Managing the Deployment](#part-6-managing-the-deployment)
10. [Part 7: Troubleshooting](#part-7-troubleshooting)
11. [Part 8: Cleanup](#part-8-cleanup)
12. [Conclusion](#conclusion)

---

## Introduction

This hands-on workshop guides you through deploying **Pentaho Server 11.0.0.0-237** with **PostgreSQL 15** on a **single-node K3s cluster**. By the end of this workshop, you will have:

- A fully functional K3s Kubernetes cluster
- Pentaho Business Analytics Platform running on Kubernetes
- PostgreSQL database with all three Pentaho repositories
- Hands-on experience with Kubernetes concepts and tools

**Workshop Duration:** 2-3 hours

**Difficulty Level:** Intermediate

---

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **OS** | Ubuntu 22.04/24.04 | Ubuntu 24.04 LTS |
| **CPU** | 4 cores | 6+ cores |
| **RAM** | 8 GB | 16+ GB |
| **Disk** | 40 GB free | 100+ GB free |
| **Network** | Internet access | Stable, fast connection |

### Required Knowledge

- Basic Linux command line skills
- Understanding of Docker and containers (helpful but not required)
- Familiarity with YAML syntax
- Basic networking concepts

### Software Prerequisites

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git vim net-tools
```

### Network Ports

Ensure these ports are available (not in use by other services):

| Port | Protocol | Purpose |
|------|----------|---------|
| 6443 | TCP | Kubernetes API Server |
| 8472 | UDP | Flannel VXLAN |
| 10250 | TCP | Kubelet metrics |
| 80 | TCP | HTTP (Traefik Ingress) |
| 443 | TCP | HTTPS (Traefik Ingress) |

---

## Workshop Overview

### What You'll Learn

1. **K3s Installation**: Install and configure lightweight Kubernetes
2. **Kubernetes Concepts**: Understand Pods, Services, Deployments, PVCs, Ingress
3. **Persistent Storage**: Configure local-path storage provisioner
4. **Database Setup**: Deploy PostgreSQL with initialization scripts
5. **Application Deployment**: Deploy multi-container applications
6. **Networking**: Configure Ingress for external access
7. **Monitoring**: Check logs and application health
8. **Management**: Backup, restore, and manage deployments

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Single-Node K3s Server                  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │               Pentaho Namespace                       │ │
│  │                                                       │ │
│  │  ┌──────────────┐         ┌────────────────────┐    │ │
│  │  │ PostgreSQL   │         │ Pentaho Server     │    │ │
│  │  │ Pod          │◄────────│ Pod                │    │ │
│  │  │              │         │                    │    │ │
│  │  │ - Port: 5432 │         │ - Port: 8080       │    │ │
│  │  │ - 3 Databases│         │ - Port: 8443       │    │ │
│  │  └──────┬───────┘         └─────────┬──────────┘    │ │
│  │         │                           │               │ │
│  │         │                           │               │ │
│  │  ┌──────▼──────┐           ┌────────▼───────┐      │ │
│  │  │ PVC (10Gi)  │           │ PVCs (15Gi)    │      │ │
│  │  │ postgres-   │           │ - pentaho-data │      │ │
│  │  │ data        │           │ - pentaho-sols │      │ │
│  │  └─────────────┘           └────────────────┘      │ │
│  │                                                     │ │
│  │  ┌───────────────────────────────────────────┐     │ │
│  │  │         Traefik Ingress                   │     │ │
│  │  │  Routes: pentaho.local → pentaho-server   │     │ │
│  │  └───────────────────────────────────────────┘     │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                         │
                         │ HTTP/HTTPS
                         ▼
                    End Users
```

---

## Part 1: Environment Setup

### Step 1.1: System Preparation

```bash
# Check system requirements
echo "=== System Information ==="
echo "OS: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "CPU Cores: $(nproc)"
echo "Total RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Available Disk: $(df -h / | awk 'NR==2 {print $4}')"
```

**Expected Output:**
```
=== System Information ===
OS: Ubuntu 24.04 LTS
Kernel: 6.14.0-37-generic
CPU Cores: 4
Total RAM: 8.0Gi
Available Disk: 50G
```

### Step 1.2: Disable Swap (Required for Kubernetes)

```bash
# Disable swap immediately
sudo swapoff -a

# Disable swap permanently
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Verify swap is disabled
free -h | grep Swap
```

**Expected Output:**
```
Swap:           0B          0B          0B
```

### Step 1.3: Configure Firewall (if enabled)

```bash
# Check if UFW is active
sudo ufw status

# If UFW is active, allow required ports
sudo ufw allow 6443/tcp    # Kubernetes API
sudo ufw allow 8472/udp    # Flannel VXLAN
sudo ufw allow 10250/tcp   # Kubelet
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
```

### Step 1.4: Clone the Repository

```bash
# Create working directory
mkdir -p ~/workshops
cd ~/workshops

# Clone the repository
git clone https://github.com/yourusername/Pentaho-K3s-PostgreSQL.git
cd Pentaho-K3s-PostgreSQL

# Verify files
ls -la
```

---

## Part 2: K3s Installation

### Step 2.1: Install K3s

K3s is a lightweight, certified Kubernetes distribution. It includes everything needed to run Kubernetes in a single binary under 100MB.

```bash
# Install K3s with default settings
curl -sfL https://get.k3s.io | sh -

# This command:
# - Downloads and installs K3s
# - Starts the K3s service
# - Installs kubectl
# - Configures kubeconfig
```

**What gets installed:**
- K3s server (control plane + worker)
- Containerd (container runtime)
- Flannel (CNI network plugin)
- CoreDNS (cluster DNS)
- Traefik (ingress controller)
- Local-path provisioner (storage)
- Metrics server

**Installation takes:** 1-2 minutes

### Step 2.2: Configure kubectl Access

```bash
# Create kube config directory
mkdir -p ~/.kube

# Copy K3s config to standard location
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Fix permissions
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Set KUBECONFIG environment variable
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Test kubectl access
kubectl version
```

**Expected Output:**
```
Client Version: v1.28.4+k3s1
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
Server Version: v1.28.4+k3s1

Note: Output format may vary by kubectl version.
In newer versions (1.28+), you'll see YAML/JSON formatted output.
```

### Step 2.3: Verify K3s Installation

Run the verification script:

```bash
# Make script executable
chmod +x scripts/verify-k3s.sh

# Run verification
./scripts/verify-k3s.sh
```

**Expected Output:**
```
=== K3s Installation Verification ===

1. Checking K3s service...
active

2. Checking nodes...
NAME       STATUS   ROLES                  AGE   VERSION
your-host  Ready    control-plane,master   2m    v1.28.4+k3s1

3. Checking system pods...
NAME                                      READY   STATUS    AGE
coredns-77ccd57875-xxxxx                 1/1     Running   2m
local-path-provisioner-957fdf8bc-xxxxx   1/1     Running   2m
metrics-server-648b5df564-xxxxx          1/1     Running   2m
traefik-64f55bb67d-xxxxx                 1/1     Running   2m

4. Checking storage class...
NAME                   PROVISIONER             RECLAIMPOLICY
local-path (default)   rancher.io/local-path   Delete

5. Checking Traefik ingress...
NAME                READY   STATUS    AGE
traefik-xxxxx       1/1     Running   2m

=== Verification Complete ===
```

### Step 2.4: Optional - Install kubectl Aliases

```bash
# Add useful aliases to bashrc
cat >> ~/.bashrc << 'EOF'

# Kubectl aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias kex='kubectl exec -it'

EOF

# Reload bashrc
source ~/.bashrc

# Test alias
k get nodes
```

---

## Part 3: Understanding the Architecture

Before deploying, let's understand the Kubernetes resources we'll create.

### 3.1: Kubernetes Objects Overview

#### Namespace
- **Purpose**: Logical isolation for resources
- **Name**: `pentaho`
- **Why**: Separate Pentaho from other applications

#### ConfigMaps (2)
1. **pentaho-config**: Environment variables for Pentaho
   - JVM memory settings
   - Database connection details
   - Application paths

2. **postgres-init**: SQL scripts for database initialization
   - Creates 3 databases: jackrabbit, quartz, hibernate
   - Creates database users
   - Creates required tables

#### Secrets (2)
1. **postgres-secrets**: PostgreSQL superuser password
2. **pentaho-db-secrets**: Database user passwords

#### PersistentVolumeClaims (3)
1. **postgres-data-pvc** (10Gi): PostgreSQL data files
2. **pentaho-data-pvc** (10Gi): Pentaho Server data
3. **pentaho-solutions-pvc** (5Gi): Reports and dashboards

#### Deployments (2)
1. **postgres**: PostgreSQL 15 database
   - 1 replica
   - Mounts postgres-data-pvc
   - Runs init scripts on first startup

2. **pentaho-server**: Pentaho Server 11.0.0.0-237
   - 1 replica
   - Init container waits for PostgreSQL
   - Mounts data and solutions PVCs

#### Services (2)
1. **postgres**: ClusterIP service for database (port 5432)
2. **pentaho-server**: ClusterIP service for web UI (ports 8080, 8443)

#### Ingress (1)
- **pentaho-ingress**: Routes HTTP traffic to pentaho-server
  - Host: pentaho.local
  - Path: /pentaho

### 3.2: Resource Flow

```
Deployment Order:
1. Namespace
2. Secrets
3. ConfigMaps
4. PersistentVolumeClaims
5. PostgreSQL Deployment + Service
6. Pentaho Deployment + Service
7. Ingress

Dependency Chain:
PVCs → PostgreSQL → Pentaho Server → Ingress → Users
```

### 3.3: Storage Architecture

K3s uses the **local-path** provisioner, which:
- Creates directories on the host filesystem
- Default location: `/var/lib/rancher/k3s/storage/`
- Each PVC gets its own directory

**Example:**
```
/var/lib/rancher/k3s/storage/
├── pvc-abc123_pentaho_postgres-data-pvc/
├── pvc-def456_pentaho_pentaho-data-pvc/
└── pvc-ghi789_pentaho_pentaho-solutions-pvc/
```

---

## Part 4: Deploying Pentaho

### Step 4.1: Review Deployment Configuration

Before deploying, let's examine the key configuration files:

```bash
# View the deployment script
cat deploy.sh

# View namespace definition
cat manifests/namespace.yaml

# View PostgreSQL ConfigMap with init scripts
cat manifests/configmaps/postgres-init.yaml

# View Pentaho ConfigMap
cat manifests/configmaps/pentaho-config.yaml
```

### Step 4.2: Configure Secrets

**IMPORTANT**: Change default passwords for production!

```bash
# Check if secrets file exists
ls manifests/secrets/

# View template
cat manifests/secrets/secrets.yaml.template

# Create secrets from template
cp manifests/secrets/secrets.yaml.template manifests/secrets/secrets.yaml

# Optional: Change passwords (recommended for production)
# Edit the file and update base64-encoded passwords:
# echo -n 'your-new-password' | base64
# vim manifests/secrets/secrets.yaml
```

**Default Passwords** (for workshop):
- PostgreSQL superuser: `password`
- All database users: `password`

### Step 4.3: Deploy All Resources

Use the automated deployment script:

```bash
# Make script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

**Deployment Process** (takes 5-7 minutes):

```
============================================
  Pentaho K3s Deployment
============================================

Running pre-flight checks...
✓ kubectl configured and cluster accessible

Deploying Pentaho to K3s...

[1/7] Creating namespace...
namespace/pentaho created
✓ Namespace created

[2/7] Creating secrets...
secret/postgres-secrets created
secret/pentaho-db-secrets created
✓ Secrets created

[3/7] Creating ConfigMaps...
configmap/pentaho-config created
configmap/postgres-init created
✓ ConfigMaps created

[4/7] Creating PersistentVolumeClaims...
persistentvolumeclaim/postgres-data-pvc created
persistentvolumeclaim/pentaho-data-pvc created
persistentvolumeclaim/pentaho-solutions-pvc created
✓ PVCs created

[5/7] Deploying PostgreSQL...
deployment.apps/postgres created
service/postgres created
✓ PostgreSQL deployment created

    Waiting for PostgreSQL to be ready...
pod/postgres-xxxxx condition met
✓ PostgreSQL is ready

[6/7] Deploying Pentaho Server...
deployment.apps/pentaho-server created
service/pentaho-server created
✓ Pentaho deployment created

[7/7] Creating Ingress...
ingress.networking.k8s.io/pentaho-ingress created
✓ Ingress created

============================================
  Deployment Complete!
============================================
```

### Step 4.4: Monitor Deployment Progress

Watch pods as they start:

```bash
# Watch pod creation (press Ctrl+C to exit)
kubectl get pods -n pentaho -w

# Check pod status
kubectl get pods -n pentaho

# Check all resources
kubectl get all -n pentaho

# Check PVC status
kubectl get pvc -n pentaho
```

**Expected Pod States:**

```
NAME                              READY   STATUS    AGE
postgres-xxxxx                    1/1     Running   2m
pentaho-server-xxxxx              0/1     Running   1m  ← Starting up
```

**Pentaho Startup Phases:**
1. **Init:0/1** - Waiting for PostgreSQL (10-30 seconds)
2. **PodInitializing** - Init container running
3. **Running** (0/1) - Container started, application loading (3-5 minutes)
4. **Running** (1/1) - Application ready

---

## Part 5: Verification and Testing

### Step 5.1: Run Validation Script

```bash
# Make script executable
chmod +x scripts/validate-deployment.sh

# Run comprehensive validation
./scripts/validate-deployment.sh
```

**Expected Output:**

```
==============================================
  Pentaho K3s Deployment Validation
==============================================

[1/6] Checking Namespace
✓ Namespace 'pentaho' exists

[2/6] Checking Pods
✓ PostgreSQL pod is running
✓ Pentaho Server pod is running

[3/6] Checking Services
✓ PostgreSQL service
✓ Pentaho Server service

[4/6] Checking PersistentVolumeClaims
✓ postgres-data-pvc is Bound
✓ pentaho-data-pvc is Bound
✓ pentaho-solutions-pvc is Bound

[5/6] Checking ConfigMaps
✓ pentaho-config ConfigMap
✓ postgres-init ConfigMap

[6/6] Checking Ingress
✓ pentaho-ingress

Testing Database Connectivity
✓ Database 'jackrabbit' accessible
✓ Database 'quartz' accessible
✓ Database 'hibernate' accessible

==============================================
  Validation Summary
==============================================
All checks passed!
```

### Step 5.2: Check Logs

Monitor Pentaho Server startup:

```bash
# Follow Pentaho Server logs
kubectl logs -f deployment/pentaho-server -n pentaho

# Check PostgreSQL logs
kubectl logs deployment/postgres -n pentaho

# Check recent events
kubectl get events -n pentaho --sort-by='.lastTimestamp' | tail -20
```

**Pentaho Startup Indicators** (look for these in logs):
```
INFO: Server startup in [XXXXX] milliseconds
INFO: Pentaho BI Platform server is ready
```

### Step 5.3: Access Pentaho Server

#### Method 1: Port Forwarding (Easiest for Testing)

```bash
# Forward local port 8080 to Pentaho Server
kubectl port-forward svc/pentaho-server 8080:8080 -n pentaho
```

**Access URL**: http://localhost:8080/pentaho

#### Method 2: Via Ingress (Production-like)

```bash
# Get node IP
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo $NODE_IP

# Add to /etc/hosts
echo "$NODE_IP pentaho.local" | sudo tee -a /etc/hosts

# Verify hosts entry
cat /etc/hosts | grep pentaho
```

**Access URL**: http://pentaho.local/pentaho

### Step 5.4: Login to Pentaho

Open browser and navigate to Pentaho:

**Default Credentials:**
- **Username**: `admin`
- **Password**: `password`

**First Login**:
1. You'll see the Pentaho User Console (PUC)
2. Navigate through the interface:
   - Home → Browse Files
   - Home → Create New
   - Administration → Users & Roles

---

## Part 6: Managing the Deployment

### 6.1: Viewing Resources

```bash
# Get all resources in pentaho namespace
kubectl get all -n pentaho

# Get detailed pod information
kubectl get pods -n pentaho -o wide

# Describe a pod (replace xxxxx with actual pod ID)
kubectl describe pod postgres-xxxxx -n pentaho
kubectl describe pod pentaho-server-xxxxx -n pentaho

# Check resource usage
kubectl top pods -n pentaho
kubectl top nodes
```

### 6.2: Accessing Pod Shells

```bash
# Get pod names
kubectl get pods -n pentaho

# Access PostgreSQL pod shell
kubectl exec -it postgres-xxxxx -n pentaho -- bash

# Inside PostgreSQL pod:
psql -U postgres
\l                          # List databases
\c jackrabbit               # Connect to database
\dt                         # List tables
SELECT current_database();  # Check current DB
\q                          # Quit psql
exit                        # Exit pod shell

# Access Pentaho Server pod shell
kubectl exec -it pentaho-server-xxxxx -n pentaho -- bash

# Inside Pentaho pod:
cd /opt/pentaho/pentaho-server
ls -la
cat tomcat/logs/catalina.out | tail -50
exit
```

### 6.3: Backup Database

```bash
# Make backup script executable
chmod +x scripts/backup-postgres.sh

# Create backup
./scripts/backup-postgres.sh
```

**Output:**
```
PostgreSQL Backup for K3s
==========================
Backing up from pod: postgres-xxxxx
Backup file: /path/to/backups/pentaho-postgres-backup-20260126-143022.sql

Creating backup...
Compressing backup...

Backup complete!
File: /path/to/backups/pentaho-postgres-backup-20260126-143022.sql.gz
Size: 2.1M

Recent backups:
-rw-r--r-- 1 user user 2.1M Jan 26 14:30 pentaho-postgres-backup-20260126-143022.sql.gz
```

### 6.4: Restore Database

```bash
# List available backups
ls -lh backups/

# Restore from backup
./scripts/restore-postgres.sh backups/pentaho-postgres-backup-20260126-143022.sql.gz

# Restart Pentaho Server after restore
kubectl rollout restart deployment/pentaho-server -n pentaho

# Monitor restart
kubectl rollout status deployment/pentaho-server -n pentaho
```

### 6.5: Scaling and Restarting

```bash
# Restart Pentaho Server
kubectl rollout restart deployment/pentaho-server -n pentaho

# Restart PostgreSQL (with downtime)
kubectl rollout restart deployment/postgres -n pentaho

# Check rollout status
kubectl rollout status deployment/pentaho-server -n pentaho

# View rollout history
kubectl rollout history deployment/pentaho-server -n pentaho

# Note: Scaling is not supported due to ReadWriteOnce volumes
# These commands will not work as intended:
# kubectl scale deployment pentaho-server --replicas=2 -n pentaho
```

---

## Part 7: Troubleshooting

### 7.1: Common Issues

#### Issue: Pods Stuck in "Pending" State

```bash
# Check pod status
kubectl get pods -n pentaho

# Describe pod to see events
kubectl describe pod pentaho-server-xxxxx -n pentaho

# Common causes:
# - Insufficient resources
# - PVC not bound
# - Node issues
```

**Solution:**
```bash
# Check PVC status
kubectl get pvc -n pentaho

# Check node resources
kubectl describe node

# Check events
kubectl get events -n pentaho --sort-by='.lastTimestamp'
```

#### Issue: Pentaho Pod Crash Loop

```bash
# Check pod logs
kubectl logs pentaho-server-xxxxx -n pentaho

# Check previous logs (if pod restarted)
kubectl logs pentaho-server-xxxxx -n pentaho --previous

# Common causes:
# - Database connection failure
# - Insufficient memory
# - Configuration errors
```

**Solution:**
```bash
# Verify PostgreSQL is running
kubectl get pods -n pentaho | grep postgres

# Test database connectivity
kubectl exec -it postgres-xxxxx -n pentaho -- psql -U postgres -c "SELECT 1"

# Check resource limits
kubectl describe pod pentaho-server-xxxxx -n pentaho | grep -A5 "Limits"
```

#### Issue: Cannot Access Pentaho UI

```bash
# Check if pod is running
kubectl get pods -n pentaho

# Check if pod is ready (1/1)
kubectl get pods -n pentaho | grep pentaho-server

# Check service
kubectl get svc -n pentaho

# Check ingress
kubectl get ingress -n pentaho
kubectl describe ingress pentaho-ingress -n pentaho
```

**Solution:**
```bash
# Test with port-forward first
kubectl port-forward svc/pentaho-server 8080:8080 -n pentaho
# Then access: http://localhost:8080/pentaho

# Check /etc/hosts for ingress method
cat /etc/hosts | grep pentaho

# Verify Traefik is running
kubectl get pods -n kube-system | grep traefik
```

### 7.2: Debugging Commands

```bash
# Get pod events
kubectl get events -n pentaho --field-selector involvedObject.name=pentaho-server-xxxxx

# Get pod YAML
kubectl get pod pentaho-server-xxxxx -n pentaho -o yaml

# Execute command in pod
kubectl exec pentaho-server-xxxxx -n pentaho -- ls -la /opt/pentaho

# Copy files from pod
kubectl cp pentaho/pentaho-server-xxxxx:/opt/pentaho/pentaho-server/tomcat/logs/catalina.out ./catalina.out

# Check resource usage
kubectl top pod -n pentaho
```

### 7.3: Advanced Troubleshooting

```bash
# Check K3s service
sudo systemctl status k3s

# Check K3s logs
sudo journalctl -u k3s -f

# Check containerd
sudo systemctl status containerd

# List containers (low-level)
sudo k3s crictl ps -a

# Check network connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside debug pod:
nslookup postgres.pentaho.svc.cluster.local
nslookup pentaho-server.pentaho.svc.cluster.local
wget -O- http://pentaho-server.pentaho.svc.cluster.local:8080/pentaho
exit
```

---

## Part 8: Cleanup

### Step 8.1: Remove Pentaho Deployment (Keep Data)

```bash
# Delete deployment but keep PVCs
./destroy.sh --keep-data
```

**Output:**
```
============================================
  Pentaho K3s Cleanup
============================================

WARNING: This will delete all Pentaho resources!
PersistentVolumeClaims will be preserved (--keep-data)

Are you sure you want to continue? (y/N) y

Deleting Pentaho resources...
Deleting deployments...
Deleting services...
Deleting ingress...
Deleting configmaps...
Deleting secrets...
Keeping PersistentVolumeClaims (--keep-data)
Deleting namespace...

============================================
  Cleanup Complete!
============================================

Note: PVCs were preserved. To fully clean up, run:
  kubectl delete pvc -n pentaho --all
```

### Step 8.2: Complete Cleanup (Delete Everything)

```bash
# Delete everything including data
./destroy.sh

# Confirm deletion when prompted
```

### Step 8.3: Uninstall K3s (Optional)

```bash
# Stop K3s
sudo systemctl stop k3s

# Uninstall K3s
sudo /usr/local/bin/k3s-uninstall.sh

# Remove kubectl config
rm -rf ~/.kube

# Verify K3s is removed
sudo systemctl status k3s  # Should show "could not be found"
```

---

## Conclusion

### What You Accomplished

✅ Installed and configured K3s single-node cluster
✅ Deployed PostgreSQL database with persistent storage
✅ Deployed Pentaho Server with proper configuration
✅ Configured Ingress for external access
✅ Learned Kubernetes resource management
✅ Performed backup and restore operations
✅ Troubleshot common deployment issues

### Key Takeaways

1. **K3s** is a lightweight Kubernetes distribution perfect for development and edge deployments
2. **PersistentVolumeClaims** provide data persistence across pod restarts
3. **ConfigMaps** and **Secrets** separate configuration from application code
4. **Init Containers** ensure dependencies are ready before main containers start
5. **Health Probes** enable automatic recovery and traffic management
6. **Ingress Controllers** provide HTTP routing without NodePort/LoadBalancer

### Next Steps

**Production Readiness:**
- [ ] Change all default passwords
- [ ] Configure TLS/HTTPS for Ingress
- [ ] Set up automated backups
- [ ] Configure resource quotas and limits
- [ ] Implement monitoring (Prometheus/Grafana)
- [ ] Set up log aggregation
- [ ] Configure network policies

**Advanced Topics:**
- [ ] Deploy multi-node K3s cluster (see WORKSHOP-MULTI-NODE.md)
- [ ] Implement Helm charts for easier management
- [ ] Set up CI/CD pipelines
- [ ] Configure external databases (RDS, CloudSQL)
- [ ] Implement GitOps with Flux/ArgoCD

### Additional Resources

**Official Documentation:**
- [K3s Documentation](https://docs.k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)

**Useful Tools:**
- [k9s](https://k9scli.io/) - Terminal UI for Kubernetes
- [Helm](https://helm.sh/) - Kubernetes package manager
- [Lens](https://k8slens.dev/) - Kubernetes IDE

### Workshop Feedback

We'd love to hear about your experience! Please share:
- What worked well
- What was confusing
- Suggestions for improvement
- Use cases you're exploring

---

**End of Workshop - Thank you for participating!**
