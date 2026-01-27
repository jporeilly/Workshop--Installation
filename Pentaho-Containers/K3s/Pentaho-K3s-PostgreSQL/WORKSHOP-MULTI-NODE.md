# Workshop: Deploying Pentaho Server on Multi-Node K3s Cluster

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Workshop Overview](#workshop-overview)
4. [Part 1: Multi-Node Architecture Planning](#part-1-multi-node-architecture-planning)
5. [Part 2: Preparing the Nodes](#part-2-preparing-the-nodes)
6. [Part 3: Setting Up the K3s Server (Control Plane)](#part-3-setting-up-the-k3s-server-control-plane)
7. [Part 4: Adding K3s Agent Nodes (Workers)](#part-4-adding-k3s-agent-nodes-workers)
8. [Part 5: Verifying the Cluster](#part-5-verifying-the-cluster)
9. [Part 6: Configuring Storage for Multi-Node](#part-6-configuring-storage-for-multi-node)
10. [Part 7: Deploying Pentaho on Multi-Node Cluster](#part-7-deploying-pentaho-on-multi-node-cluster)
11. [Part 8: High Availability Considerations](#part-8-high-availability-considerations)
12. [Part 9: Managing Multi-Node Deployments](#part-9-managing-multi-node-deployments)
13. [Part 10: Monitoring and Maintenance](#part-10-monitoring-and-maintenance)
14. [Part 11: Troubleshooting Multi-Node Issues](#part-11-troubleshooting-multi-node-issues)
15. [Conclusion](#conclusion)

---

## Introduction

This advanced workshop guides you through deploying **Pentaho Server** on a **multi-node K3s cluster**. Unlike single-node deployments, multi-node clusters provide:

- **Workload Distribution**: Spread applications across multiple machines
- **Resource Isolation**: Separate control plane from workloads
- **Better Resource Utilization**: Use available hardware efficiently
- **Foundation for HA**: First step toward high availability
- **Production-Like Environment**: More realistic testing scenarios

**Workshop Duration:** 3-4 hours

**Difficulty Level:** Advanced

---

## Prerequisites

### Infrastructure Requirements

You'll need **at least 3 machines** (physical, VMs, or cloud instances):

| Node Type | Quantity | Purpose |
|-----------|----------|---------|
| **Server Node** | 1+ | K3s control plane (master) |
| **Agent Nodes** | 2+ | Worker nodes for running workloads |

**Recommended Configuration** (for this workshop):
- 1 Server Node (control plane)
- 2 Agent Nodes (workers)

### Per-Node Requirements

| Component | Server Node | Agent Nodes |
|-----------|-------------|-------------|
| **OS** | Ubuntu 22.04/24.04 | Ubuntu 22.04/24.04 |
| **CPU** | 2+ cores | 2+ cores |
| **RAM** | 4 GB | 4 GB |
| **Disk** | 40 GB | 40 GB |
| **Network** | Static IP or hostname | Static IP or hostname |

### Network Requirements

**Critical**: All nodes must be able to communicate with each other.

#### Required Ports

**Server Node (Control Plane):**

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 6443 | TCP | Inbound | Kubernetes API Server |
| 10250 | TCP | Inbound | Kubelet metrics |

**Agent Nodes (Workers):**

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 10250 | TCP | Inbound | Kubelet metrics |

**All Nodes:**

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 8472 | UDP | Both | Flannel VXLAN overlay network |
| 51820 | UDP | Both | Flannel WireGuard (if enabled) |
| 51821 | UDP | Both | Flannel WireGuard (if enabled) |

**External Access:**

| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 80 | TCP | Inbound | HTTP (Traefik Ingress) |
| 443 | TCP | Inbound | HTTPS (Traefik Ingress) |

### Network Topology Example

```
┌─────────────────┐
│   User/Client   │
└────────┬────────┘
         │ HTTP/HTTPS (80/443)
         ▼
┌──────────────────────────────────────────────────────┐
│              Load Balancer (Optional)                │
│              or Direct Node Access                   │
└─────────┬────────────────────────┬───────────────────┘
          │                        │
          ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Server Node    │    │  Agent Node 1   │    │  Agent Node 2   │
│  (Control Plane)│◄──►│  (Worker)       │◄──►│  (Worker)       │
│  192.168.1.10   │    │  192.168.1.11   │    │  192.168.1.12   │
│                 │    │                 │    │                 │
│  - API Server   │    │  - Kubelet      │    │  - Kubelet      │
│  - Scheduler    │    │  - Container    │    │  - Container    │
│  - Controller   │    │    Runtime      │    │    Runtime      │
│  - etcd         │    │  - Workload     │    │  - Workload     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
                 Flannel VXLAN Network (8472/UDP)
```

### SSH Access

You must have **SSH access** to all nodes:

```bash
# Test SSH connectivity
ssh user@192.168.1.10  # Server node
ssh user@192.168.1.11  # Agent node 1
ssh user@192.168.1.12  # Agent node 2
```

### Required Knowledge

- Linux system administration
- Basic networking (IP addresses, subnets, DNS)
- SSH and remote server management
- Single-node K3s deployment (complete WORKSHOP-SINGLE-NODE.md first)
- Kubernetes concepts (Pods, Services, Deployments)

---

## Workshop Overview

### What You'll Learn

1. **Multi-Node Planning**: Design cluster topology
2. **K3s Server Setup**: Install control plane node
3. **K3s Agent Setup**: Join worker nodes to cluster
4. **Network Configuration**: Ensure node-to-node communication
5. **Storage Strategy**: Handle persistent storage across nodes
6. **Pod Scheduling**: Control where pods run
7. **Node Management**: Add/remove nodes, drain, cordon
8. **Production Patterns**: Best practices for multi-node deployments

### Architecture Overview

```
┌───────────────────────────────────────────────────────────────────┐
│                      Multi-Node K3s Cluster                       │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    Server Node (Control Plane)              │ │
│  │                                                             │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐    │ │
│  │  │ API Server  │  │ Scheduler   │  │ Controller     │    │ │
│  │  └─────────────┘  └─────────────┘  │ Manager        │    │ │
│  │  ┌─────────────┐  ┌─────────────┐  └────────────────┘    │ │
│  │  │ etcd        │  │ Cloud       │                         │ │
│  │  │ (datastore) │  │ Controller  │                         │ │
│  │  └─────────────┘  └─────────────┘                         │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                              │                                    │
│              ┌───────────────┴───────────────┐                   │
│              │                               │                   │
│  ┌───────────▼──────────────┐   ┌───────────▼──────────────┐   │
│  │   Agent Node 1 (Worker)  │   │   Agent Node 2 (Worker)  │   │
│  │                          │   │                          │   │
│  │  ┌──────────────────┐   │   │  ┌──────────────────┐   │   │
│  │  │ PostgreSQL Pod   │   │   │  │ Pentaho Server   │   │   │
│  │  │ (Pinned to       │   │   │  │ Pod              │   │   │
│  │  │  Agent 1)        │   │   │  │                  │   │   │
│  │  └────────┬─────────┘   │   │  └─────────┬────────┘   │   │
│  │           │             │   │            │            │   │
│  │  ┌────────▼─────────┐   │   │  ┌─────────▼────────┐   │   │
│  │  │ Local PVC        │   │   │  │ Local PVCs       │   │   │
│  │  │ (postgres-data)  │   │   │  │ (data,solutions) │   │   │
│  │  └──────────────────┘   │   │  └──────────────────┘   │   │
│  └──────────────────────────┘   └──────────────────────────┘   │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │                 Traefik Ingress Controller                │ │
│  │          (Can run on any node, routes traffic)            │ │
│  └───────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────┘
```

---

## Part 1: Multi-Node Architecture Planning

### 1.1: Cluster Topology Decision

**For this workshop, we'll use:**

| Node | Role | IP Address | Purpose |
|------|------|------------|---------|
| node1 | Server | 192.168.1.10 | Control plane (master) |
| node2 | Agent | 192.168.1.11 | Worker (PostgreSQL) |
| node3 | Agent | 192.168.1.12 | Worker (Pentaho Server) |

**Update these IPs** to match your environment!

### 1.2: Storage Strategy

**Challenge**: K3s's default `local-path` provisioner creates volumes on the node where the pod runs.

**Solutions:**

1. **Option A: Node Affinity** (Used in this workshop)
   - Pin PostgreSQL pod to specific node
   - Pin Pentaho pod to same or different node
   - Use local-path storage on each node

2. **Option B: Network Storage**
   - Deploy NFS server
   - Use NFS provisioner
   - Pods can move between nodes

3. **Option C: Cloud Storage**
   - Use Longhorn, Rook/Ceph, or cloud provider storage
   - More complex but production-ready

**We'll use Option A** (simplest for workshop).

### 1.3: Workload Distribution

**Placement Strategy:**

- **PostgreSQL**: Pin to Agent Node 1 (stateful, needs stable storage)
- **Pentaho Server**: Pin to Agent Node 2 or allow scheduling
- **System Pods**: Can run on server or agent nodes

---

## Part 2: Preparing the Nodes

### Step 2.1: Set Up Environment Variables

On your **local machine** (from where you'll SSH), set these variables:

```bash
# Update with your actual IP addresses or hostnames
export SERVER_NODE="192.168.1.10"
export AGENT_NODE_1="192.168.1.11"
export AGENT_NODE_2="192.168.1.12"
export SSH_USER="your-username"

# Verify
echo "Server: $SERVER_NODE"
echo "Agent 1: $AGENT_NODE_1"
echo "Agent 2: $AGENT_NODE_2"
```

### Step 2.2: Configure SSH Key Authentication (Optional but Recommended)

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "k3s-cluster"

# Copy SSH key to all nodes
ssh-copy-id $SSH_USER@$SERVER_NODE
ssh-copy-id $SSH_USER@$AGENT_NODE_1
ssh-copy-id $SSH_USER@$AGENT_NODE_2

# Test passwordless SSH
ssh $SSH_USER@$SERVER_NODE "echo 'Server node connected'"
ssh $SSH_USER@$AGENT_NODE_1 "echo 'Agent 1 connected'"
ssh $SSH_USER@$AGENT_NODE_2 "echo 'Agent 2 connected'"
```

### Step 2.3: Prepare All Nodes

Run these commands **on each node** (server + all agents):

```bash
# SSH into each node and run:
ssh $SSH_USER@$SERVER_NODE    # Then run commands below
ssh $SSH_USER@$AGENT_NODE_1   # Then run commands below
ssh $SSH_USER@$AGENT_NODE_2   # Then run commands below

# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git net-tools

# Disable swap (required for Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Verify swap is disabled
free -h | grep Swap  # Should show 0B

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure firewall (if UFW is enabled)
sudo ufw status

# If UFW is active, allow required ports
# On ALL nodes:
sudo ufw allow 8472/udp   # Flannel VXLAN

# On SERVER node only:
sudo ufw allow 6443/tcp   # Kubernetes API
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS

# On AGENT nodes:
sudo ufw allow 10250/tcp  # Kubelet metrics

# Set hostnames (optional but helpful)
# On server node:
sudo hostnamectl set-hostname k3s-server

# On agent 1:
sudo hostnamectl set-hostname k3s-agent-1

# On agent 2:
sudo hostnamectl set-hostname k3s-agent-2

# Update /etc/hosts on all nodes (adjust IPs to match your environment)
cat << EOF | sudo tee -a /etc/hosts
192.168.1.10 k3s-server
192.168.1.11 k3s-agent-1
192.168.1.12 k3s-agent-2
EOF

# Test connectivity between nodes
ping -c 3 k3s-server
ping -c 3 k3s-agent-1
ping -c 3 k3s-agent-2
```

---

## Part 3: Setting Up the K3s Server (Control Plane)

### Step 3.1: Install K3s on Server Node

SSH into the **server node**:

```bash
ssh $SSH_USER@$SERVER_NODE
```

Install K3s server:

```bash
# Install K3s with external hostname/IP
# This allows agents to connect via this address
curl -sfL https://get.k3s.io | sh -s - server \
  --tls-san $SERVER_NODE \
  --node-name k3s-server

# Alternative: If using hostname
# curl -sfL https://get.k3s.io | sh -s - server \
#   --tls-san k3s-server \
#   --node-name k3s-server

# Installation takes 1-2 minutes
```

**Installation includes:**
- K3s server (API server, scheduler, controller manager, etcd)
- kubectl
- containerd runtime
- Flannel CNI
- CoreDNS
- Traefik ingress
- Local-path provisioner

### Step 3.2: Retrieve Node Token

The agent nodes need a token to join the cluster:

```bash
# Get the node token (on server node)
sudo cat /var/lib/rancher/k3s/server/node-token
```

**Output example:**
```
K10abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890::server:1234567890abcdef
```

**Save this token** - you'll need it for adding agent nodes!

### Step 3.3: Configure kubectl on Server Node

```bash
# Create kube config directory
mkdir -p ~/.kube

# Copy K3s config
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Test kubectl
kubectl version
kubectl get nodes
```

**Expected Output:**
```
NAME         STATUS   ROLES                  AGE   VERSION
k3s-server   Ready    control-plane,master   1m    v1.28.4+k3s1
```

### Step 3.4: Configure kubectl on Your Local Machine (Optional)

For convenience, you can manage the cluster from your local machine:

```bash
# On your local machine
mkdir -p ~/.kube

# Copy kubeconfig from server node
scp $SSH_USER@$SERVER_NODE:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-config

# Update server address in config
# Replace 127.0.0.1 with your server node IP
sed -i "s/127.0.0.1/$SERVER_NODE/g" ~/.kube/k3s-config

# Set KUBECONFIG
export KUBECONFIG=~/.kube/k3s-config

# Add to bashrc for persistence
echo "export KUBECONFIG=~/.kube/k3s-config" >> ~/.bashrc

# Test from local machine
kubectl get nodes
```

---

## Part 4: Adding K3s Agent Nodes (Workers)

### Step 4.1: Install K3s Agent on Node 1

SSH into **Agent Node 1**:

```bash
ssh $SSH_USER@$AGENT_NODE_1
```

Join the cluster:

```bash
# Replace K10xxx... with your actual token from Step 3.2
export K3S_URL="https://192.168.1.10:6443"  # Update with your server IP
export K3S_TOKEN="K10abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890::server:1234567890abcdef"

# Install K3s agent
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -s - agent --node-name k3s-agent-1

# Alternative one-liner:
# curl -sfL https://get.k3s.io | K3S_URL="https://192.168.1.10:6443" \
#   K3S_TOKEN="your-token-here" sh -s - agent --node-name k3s-agent-1
```

**Installation takes 30-60 seconds**

### Step 4.2: Install K3s Agent on Node 2

SSH into **Agent Node 2**:

```bash
ssh $SSH_USER@$AGENT_NODE_2
```

Join the cluster:

```bash
# Use the same token and server URL
export K3S_URL="https://192.168.1.10:6443"
export K3S_TOKEN="your-token-from-step-3.2"

# Install K3s agent
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -s - agent --node-name k3s-agent-2
```

### Step 4.3: Verify Cluster Nodes

From the **server node** or your **local machine** (if configured):

```bash
# List all nodes
kubectl get nodes

# Get detailed node information
kubectl get nodes -o wide

# Describe a specific node
kubectl describe node k3s-agent-1
```

**Expected Output:**
```
NAME           STATUS   ROLES                  AGE     VERSION
k3s-server     Ready    control-plane,master   5m      v1.28.4+k3s1
k3s-agent-1    Ready    <none>                 2m      v1.28.4+k3s1
k3s-agent-2    Ready    <none>                 1m      v1.28.4+k3s1
```

**All nodes should show STATUS: Ready**

---

## Part 5: Verifying the Cluster

### Step 5.1: Check System Pods

```bash
# System pods run in kube-system namespace
kubectl get pods -n kube-system -o wide

# Look for pods distributed across nodes
kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase
```

**Expected Output:**
```
NAME                                     NODE           STATUS
coredns-xxxxx                           k3s-agent-1    Running
local-path-provisioner-xxxxx            k3s-agent-2    Running
metrics-server-xxxxx                    k3s-server     Running
traefik-xxxxx                           k3s-agent-1    Running
```

### Step 5.2: Test Pod Scheduling

Create a test deployment to verify scheduling works:

```bash
# Create test deployment with 3 replicas
kubectl create deployment nginx-test --image=nginx --replicas=3

# Wait for pods to be ready
kubectl rollout status deployment/nginx-test

# Check pod distribution across nodes
kubectl get pods -l app=nginx-test -o wide

# Expected: Pods distributed across available nodes
```

**Expected Output:**
```
NAME                          READY   STATUS    NODE
nginx-test-xxxxx-aaaaa        1/1     Running   k3s-agent-1
nginx-test-xxxxx-bbbbb        1/1     Running   k3s-agent-2
nginx-test-xxxxx-ccccc        1/1     Running   k3s-agent-1
```

Delete test deployment:

```bash
kubectl delete deployment nginx-test
```

### Step 5.3: Test Node Communication

```bash
# Create a test pod
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh

# Inside the pod, test DNS and connectivity
nslookup kubernetes.default.svc.cluster.local
nslookup kube-dns.kube-system.svc.cluster.local
ping -c 3 8.8.8.8
exit
```

---

## Part 6: Configuring Storage for Multi-Node

### 6.1: Understanding Local-Path Storage in Multi-Node

**Important**: K3s's local-path provisioner creates volumes on the node where the pod is scheduled.

**Challenge**: If a pod moves to another node, it loses access to its original volume.

**Solution for this workshop**: Use node affinity to pin stateful pods to specific nodes.

### 6.2: Label Nodes for PostgreSQL and Pentaho

```bash
# Label agent-1 for PostgreSQL workload
kubectl label node k3s-agent-1 workload=database

# Label agent-2 for Pentaho workload
kubectl label node k3s-agent-2 workload=pentaho

# Verify labels
kubectl get nodes --show-labels
```

### 6.3: Clone Repository on Management Node

On the machine where you run `kubectl` (server node or local machine):

```bash
# Create working directory
mkdir -p ~/workshops
cd ~/workshops

# Clone repository
git clone https://github.com/yourusername/Pentaho-K3s-PostgreSQL.git
cd Pentaho-K3s-PostgreSQL
```

### 6.4: Modify Manifests for Multi-Node

We need to add node affinity to pin PostgreSQL and Pentaho to specific nodes.

**Edit PostgreSQL Deployment:**

```bash
vim manifests/postgres/deployment.yaml
```

Add `nodeSelector` to the PostgreSQL spec (after `spec:` and before `containers:`):

```yaml
spec:
  template:
    spec:
      nodeSelector:
        workload: database
      containers:
        - name: postgres
          # ... rest of configuration
```

**Edit Pentaho Deployment:**

```bash
vim manifests/pentaho/deployment.yaml
```

Add `nodeSelector` to the Pentaho spec:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        workload: pentaho
      initContainers:
        # ... init containers
      containers:
        - name: pentaho-server
          # ... rest of configuration
```

---

## Part 7: Deploying Pentaho on Multi-Node Cluster

### Step 7.1: Prepare Secrets

```bash
# Copy template to create secrets file
cp manifests/secrets/secrets.yaml.template manifests/secrets/secrets.yaml

# For production, change passwords:
# vim manifests/secrets/secrets.yaml
```

### Step 7.2: Deploy Pentaho

```bash
# Make scripts executable
chmod +x deploy.sh scripts/*.sh

# Run deployment
./deploy.sh
```

**Deployment Output:**
```
============================================
  Pentaho K3s Deployment
============================================

Running pre-flight checks...
✓ kubectl configured and cluster accessible

Deploying Pentaho to K3s...

[1/7] Creating namespace...
[2/7] Creating secrets...
[3/7] Creating ConfigMaps...
[4/7] Creating PersistentVolumeClaims...
[5/7] Deploying PostgreSQL...
    Waiting for PostgreSQL to be ready...
✓ PostgreSQL is ready
[6/7] Deploying Pentaho Server...
[7/7] Creating Ingress...

============================================
  Deployment Complete!
============================================
```

### Step 7.3: Verify Pod Placement

```bash
# Check which nodes pods are running on
kubectl get pods -n pentaho -o wide

# Expected output shows pods on labeled nodes
```

**Expected Output:**
```
NAME                              READY   STATUS    NODE
postgres-xxxxx                    1/1     Running   k3s-agent-1
pentaho-server-xxxxx              1/1     Running   k3s-agent-2
```

### Step 7.4: Verify Storage

```bash
# Check PVCs
kubectl get pvc -n pentaho

# Check PVs
kubectl get pv
```

**Storage locations on nodes:**

```bash
# SSH to agent-1 (PostgreSQL node)
ssh $SSH_USER@$AGENT_NODE_1
sudo ls -la /var/lib/rancher/k3s/storage/

# SSH to agent-2 (Pentaho node)
ssh $SSH_USER@$AGENT_NODE_2
sudo ls -la /var/lib/rancher/k3s/storage/
```

---

## Part 8: High Availability Considerations

### 8.1: Current Architecture Limitations

**Single Points of Failure:**

1. **Control Plane**: One server node
   - If server node fails, API is unavailable
   - Existing workloads continue running
   - Cannot deploy new workloads until recovered

2. **PostgreSQL**: Single pod, pinned to one node
   - If agent-1 fails, PostgreSQL is unavailable
   - No automatic failover

3. **Pentaho Server**: Single pod, pinned to one node
   - If agent-2 fails, Pentaho is unavailable

### 8.2: Path to High Availability

**For Production HA, consider:**

1. **Multiple Server Nodes** (K3s HA)
   ```bash
   # First server (embedded etcd)
   curl -sfL https://get.k3s.io | sh -s - server \
     --cluster-init \
     --tls-san load-balancer-ip

   # Additional servers (join cluster)
   curl -sfL https://get.k3s.io | sh -s - server \
     --server https://first-server:6443 \
     --token <token>
   ```

2. **External Database (PostgreSQL HA)**
   - Use external managed PostgreSQL (AWS RDS, Google CloudSQL)
   - Or deploy PostgreSQL with replication (StatefulSet + Patroni)

3. **Shared Storage**
   - Deploy NFS or Longhorn for shared persistent volumes
   - Enables pod mobility across nodes

4. **Load Balancer**
   - HAProxy or cloud load balancer
   - Distributes traffic across multiple ingress nodes

### 8.3: Example HA Architecture (Future State)

```
                         ┌─────────────────┐
                         │  Load Balancer  │
                         └────────┬────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
       ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐
       │  Server 1   │    │  Server 2   │    │  Server 3   │
       │  (Master)   │◄──►│  (Master)   │◄──►│  (Master)   │
       └─────────────┘    └─────────────┘    └─────────────┘
              │                   │                   │
       ┌──────┴───────────────────┴───────────────────┴──────┐
       │                                                      │
┌──────▼──────┐    ┌─────────────┐    ┌─────────────┐    ┌──▼───────────┐
│  Agent 1    │    │  Agent 2    │    │  Agent 3    │    │  Agent N     │
│  (Worker)   │    │  (Worker)   │    │  (Worker)   │    │  (Worker)    │
└─────────────┘    └─────────────┘    └─────────────┘    └──────────────┘
       │                   │                   │                   │
       └───────────────────┴───────────────────┴───────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   Shared Storage  │
                    │   (NFS/Longhorn)  │
                    └───────────────────┘
```

---

## Part 9: Managing Multi-Node Deployments

### 9.1: Viewing Cluster Resources

```bash
# Node information
kubectl get nodes
kubectl top nodes         # Resource usage
kubectl describe node k3s-agent-1

# Pod distribution
kubectl get pods -A -o wide | grep -v kube-system

# Resource usage by node
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu
```

### 9.2: Node Maintenance - Draining a Node

When you need to perform maintenance on a node:

```bash
# Drain node (evicts pods, marks unschedulable)
kubectl drain k3s-agent-2 --ignore-daemonsets --delete-emptydir-data

# Pods on that node will be rescheduled to other nodes
# Check where pods moved
kubectl get pods -n pentaho -o wide

# After maintenance, make node schedulable again
kubectl uncordon k3s-agent-2
```

**Note**: With our current setup (local-path storage + node affinity), Pentaho pod won't move because it's pinned to agent-2.

### 9.3: Removing a Node from the Cluster

```bash
# Drain the node first
kubectl drain k3s-agent-2 --ignore-daemonsets --delete-emptydir-data --force

# Delete node from cluster (from management node)
kubectl delete node k3s-agent-2

# On the actual agent node, uninstall K3s
ssh $SSH_USER@$AGENT_NODE_2
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

### 9.4: Adding a New Agent Node

```bash
# On new node, install K3s agent
export K3S_URL="https://192.168.1.10:6443"
export K3S_TOKEN="your-server-token"

curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -s - agent --node-name k3s-agent-3

# Label the new node
kubectl label node k3s-agent-3 workload=compute

# Verify
kubectl get nodes
```

---

## Part 10: Monitoring and Maintenance

### 10.1: Monitor Pod Logs Across Nodes

```bash
# Follow Pentaho logs
kubectl logs -f deployment/pentaho-server -n pentaho

# View logs from all pods in namespace
kubectl logs -l app.kubernetes.io/name=pentaho -n pentaho --all-containers=true

# Get logs from specific node
kubectl get pods -n pentaho -o wide  # Find pod name
kubectl logs postgres-xxxxx -n pentaho
```

### 10.2: Backup PostgreSQL

```bash
# Backup works the same as single-node
./scripts/backup-postgres.sh

# Backup is created on the management node, not on agent-1
```

### 10.3: Restore PostgreSQL

```bash
# Restore from backup
./scripts/restore-postgres.sh backups/pentaho-postgres-backup-XXXXXX.sql.gz

# Restart Pentaho
kubectl rollout restart deployment/pentaho-server -n pentaho
```

### 10.4: Monitor Cluster Health

```bash
# Check node status
kubectl get nodes

# Check component status (deprecated but still useful)
kubectl get componentstatuses

# Check system pods
kubectl get pods -n kube-system

# Check events for issues
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# View cluster info
kubectl cluster-info

# Check resource quotas and limits
kubectl describe nodes
```

### 10.5: Install K9s (Optional CLI Tool)

K9s provides a terminal UI for managing Kubernetes:

```bash
# Install k9s
wget https://github.com/derailed/k9s/releases/download/v0.31.9/k9s_Linux_amd64.tar.gz
tar xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/
rm k9s_Linux_amd64.tar.gz

# Run k9s
k9s
```

**K9s Commands:**
- `:pods` - View pods
- `:nodes` - View nodes
- `:svc` - View services
- `/<pattern>` - Filter resources
- `l` - View logs
- `d` - Describe resource
- `y` - View YAML
- `:q` - Quit

---

## Part 11: Troubleshooting Multi-Node Issues

### 11.1: Node Communication Issues

**Symptom**: Nodes show "NotReady" status or pods can't communicate.

**Check:**

```bash
# Verify node status
kubectl get nodes
kubectl describe node k3s-agent-1

# Check Flannel (overlay network)
kubectl get pods -n kube-system | grep flannel

# Test connectivity from one pod to another
kubectl run test-pod --image=busybox --rm -it --restart=Never -- sh
# Inside pod:
ping 10.42.1.1  # Replace with another pod's IP
nslookup kubernetes.default
exit

# Check Flannel VXLAN interface on nodes
ssh $SSH_USER@$AGENT_NODE_1
ip -d link show flannel.1
ip addr show flannel.1
```

**Solution:**

```bash
# Ensure UDP port 8472 is open on all nodes
sudo ufw allow 8472/udp

# Restart K3s on affected node
sudo systemctl restart k3s      # On server
sudo systemctl restart k3s-agent  # On agent
```

### 11.2: Pod Stuck in Pending (Node Affinity Issues)

**Symptom**: Pod stuck in "Pending" state.

**Check:**

```bash
# Describe the pending pod
kubectl describe pod postgres-xxxxx -n pentaho

# Look for events like:
#   Warning  FailedScheduling  ... 0/3 nodes available:
#   3 node(s) didn't match node selector
```

**Solution:**

```bash
# Verify node labels
kubectl get nodes --show-labels | grep workload

# If label is missing, add it:
kubectl label node k3s-agent-1 workload=database

# Delete and recreate pod (it will be rescheduled)
kubectl delete pod postgres-xxxxx -n pentaho
```

### 11.3: Storage Issues Across Nodes

**Symptom**: Pod moved to different node, loses data.

**Check:**

```bash
# Check PVC status
kubectl get pvc -n pentaho

# Check which node the pod is on
kubectl get pod -n pentaho -o wide

# Check PV node affinity
kubectl get pv -o yaml | grep -A5 nodeAffinity
```

**Solution:**

With local-path storage, pods **must** stay on the same node as their PVs.

**Option 1**: Use node affinity (already configured in workshop)

**Option 2**: Deploy network storage (NFS, Longhorn)

```bash
# Example: Install Longhorn (distributed storage)
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml

# Wait for Longhorn to be ready
kubectl get pods -n longhorn-system -w

# Set Longhorn as default storage class
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

### 11.4: Cluster Networking Debugging

```bash
# Create a network debugging pod
kubectl run netshoot --rm -i --tty --image nicolaka/netshoot -- /bin/bash

# Inside netshoot pod:
# Test DNS
nslookup kubernetes.default
nslookup pentaho-server.pentaho.svc.cluster.local

# Test connectivity to services
curl http://pentaho-server.pentaho.svc.cluster.local:8080/pentaho
curl http://postgres.pentaho.svc.cluster.local:5432

# Trace route
traceroute pentaho-server.pentaho.svc.cluster.local

# Check DNS resolution
dig pentaho-server.pentaho.svc.cluster.local

exit
```

### 11.5: Control Plane Issues

**Symptom**: Cannot run kubectl commands, API server unavailable.

**Check:**

```bash
# SSH to server node
ssh $SSH_USER@$SERVER_NODE

# Check K3s service status
sudo systemctl status k3s

# View K3s logs
sudo journalctl -u k3s -f

# Check K3s processes
ps aux | grep k3s
```

**Solution:**

```bash
# Restart K3s service
sudo systemctl restart k3s

# If that doesn't work, check disk space
df -h

# Check memory
free -h

# View detailed logs
sudo journalctl -u k3s --since "10 minutes ago"
```

---

## Conclusion

### What You Accomplished

✅ **Built a multi-node K3s cluster** with 1 server and 2 agent nodes
✅ **Configured node-to-node networking** with Flannel VXLAN
✅ **Deployed stateful applications** across multiple nodes
✅ **Implemented node affinity** for stable pod placement
✅ **Managed persistent storage** in multi-node environment
✅ **Learned cluster management** (draining, labeling, monitoring)
✅ **Troubleshot multi-node issues** (networking, scheduling, storage)

### Key Multi-Node Concepts

1. **Cluster Topology**: Server nodes (control plane) vs. Agent nodes (workers)
2. **Node Labels and Selectors**: Control pod placement
3. **Network Overlay**: Flannel creates virtual network across nodes
4. **Storage Locality**: Local-path volumes are node-specific
5. **Pod Scheduling**: Kubernetes scheduler distributes workloads
6. **Node Maintenance**: Draining and cordoning for safe maintenance

### Comparison: Single-Node vs. Multi-Node

| Aspect | Single-Node | Multi-Node |
|--------|-------------|------------|
| **Setup Complexity** | Simple | Moderate |
| **Resource Isolation** | None | Server separate from workloads |
| **Scalability** | Limited | Horizontal scaling possible |
| **High Availability** | No | Foundation for HA |
| **Resource Usage** | Concentrated | Distributed |
| **Network** | Localhost | Overlay network required |
| **Storage** | Simple (local) | Complex (affinity or shared storage) |
| **Use Case** | Dev, testing, edge | Staging, production |

### Production Readiness Checklist

**Infrastructure:**
- [ ] Multiple server nodes for control plane HA
- [ ] Load balancer for API server and Ingress
- [ ] Shared storage (NFS, Longhorn, Ceph, or cloud storage)
- [ ] Backup and disaster recovery plan
- [ ] Monitoring and alerting (Prometheus, Grafana)

**Security:**
- [ ] Change all default passwords
- [ ] Configure RBAC (Role-Based Access Control)
- [ ] Enable TLS for Ingress
- [ ] Implement Network Policies
- [ ] Regular security updates

**Application:**
- [ ] PostgreSQL with replication or external managed DB
- [ ] Horizontal Pod Autoscaler (if stateless components)
- [ ] Resource quotas and limits
- [ ] Health check tuning
- [ ] Logging aggregation (ELK, Loki)

### Next Steps

**Advanced Topics:**

1. **High Availability K3s**
   ```bash
   # Multi-server setup with embedded etcd
   curl -sfL https://get.k3s.io | sh -s - server --cluster-init
   ```

2. **External Database for K3s**
   ```bash
   # Use external etcd or database
   curl -sfL https://get.k3s.io | sh -s - server \
     --datastore-endpoint="postgres://user:pass@host:5432/k3s"
   ```

3. **Deploy Longhorn for Distributed Storage**
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
   ```

4. **Helm for Application Management**
   ```bash
   # Install Helm
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

   # Create Helm chart for Pentaho
   helm create pentaho-chart
   ```

5. **GitOps with Flux or ArgoCD**
   ```bash
   # Install Flux
   flux bootstrap github \
     --owner=your-username \
     --repository=pentaho-k3s \
     --path=clusters/production
   ```

### Additional Resources

**K3s Documentation:**
- [K3s Installation](https://docs.k3s.io/installation)
- [K3s Cluster Architecture](https://docs.k3s.io/architecture)
- [K3s High Availability](https://docs.k3s.io/installation/ha-embedded)

**Kubernetes Learning:**
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Patterns](https://k8spatterns.io/)
- [Production Best Practices](https://kubernetes.io/docs/setup/best-practices/)

**Storage Solutions:**
- [Longhorn Documentation](https://longhorn.io/docs/)
- [Rook/Ceph](https://rook.io/)
- [NFS Subdir External Provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner)

### Cleanup

**Remove Pentaho Deployment:**
```bash
./destroy.sh
```

**Remove Agent Nodes:**
```bash
# Drain and delete
kubectl drain k3s-agent-2 --ignore-daemonsets --force --delete-emptydir-data
kubectl delete node k3s-agent-2

# SSH and uninstall
ssh $SSH_USER@$AGENT_NODE_2
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

**Uninstall K3s Cluster:**
```bash
# On server node
sudo /usr/local/bin/k3s-uninstall.sh

# On agent nodes
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

---

**End of Multi-Node Workshop - Thank you for participating!**

**Congratulations on building a multi-node Kubernetes cluster!** 🎉
