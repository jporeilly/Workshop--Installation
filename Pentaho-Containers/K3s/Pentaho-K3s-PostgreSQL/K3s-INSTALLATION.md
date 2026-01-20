# K3s Installation Guide for Ubuntu 24.04 LTS

This guide covers installing K3s (lightweight Kubernetes) on Ubuntu 24.04 LTS for running Pentaho Server.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
- [Single-Node Installation](#single-node-installation)
- [Multi-Node Cluster](#multi-node-cluster)
- [Post-Installation Configuration](#post-installation-configuration)
- [Verify Installation](#verify-installation)
- [K3s Management](#k3s-management)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

## Overview

### What is K3s?

K3s is a lightweight, certified Kubernetes distribution designed for:

- **Edge computing** and IoT devices
- **CI/CD environments**
- **Development** and testing
- **Resource-constrained** environments
- **Single-node** or small clusters

### K3s vs Full Kubernetes

| Feature | K3s | K8s (kubeadm) |
|---------|-----|---------------|
| Binary Size | ~60MB | 500MB+ |
| Memory Usage | ~512MB | 2GB+ |
| Installation | Single command | Multiple steps |
| Dependencies | None | Container runtime, etc. |
| Default Storage | SQLite/etcd | etcd |
| Ingress | Traefik (included) | Manual install |
| Load Balancer | ServiceLB (included) | Manual install |

### Components Included with K3s

- **containerd** - Container runtime
- **Flannel** - CNI networking
- **CoreDNS** - DNS service
- **Traefik** - Ingress controller
- **ServiceLB** - Load balancer
- **Local-path provisioner** - Storage
- **Metrics Server** - Resource metrics

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 1 core | 4+ cores |
| RAM | 512MB | 8GB+ |
| Disk | 10GB | 50GB+ |
| OS | Ubuntu 20.04+ | Ubuntu 24.04 LTS |

### Network Requirements

- Outbound internet access (for installation)
- Ports:
  - **6443**: Kubernetes API server
  - **8472**: Flannel VXLAN (if multi-node)
  - **10250**: Kubelet metrics
  - **80/443**: Ingress (Traefik)

### Prepare Ubuntu 24.04

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget apt-transport-https ca-certificates

# Disable swap (recommended for Kubernetes)
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Enable IP forwarding
sudo tee /etc/sysctl.d/k3s.conf <<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system

# Configure firewall (if using UFW)
sudo ufw allow 6443/tcp    # Kubernetes API
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 10250/tcp   # Kubelet
```

## Installation Methods

### Method 1: Default Installation (Recommended)

Standard installation with all defaults:

```bash
curl -sfL https://get.k3s.io | sh -
```

### Method 2: Custom Installation

Install with specific options:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
```

### Method 3: Air-Gapped Installation

For systems without internet access:

```bash
# On a connected system, download the binary
wget https://github.com/k3s-io/k3s/releases/download/v1.29.0+k3s1/k3s
wget https://github.com/k3s-io/k3s/releases/download/v1.29.0+k3s1/k3s-airgap-images-amd64.tar.gz

# Transfer to air-gapped system, then:
sudo mkdir -p /var/lib/rancher/k3s/agent/images/
sudo cp k3s-airgap-images-amd64.tar.gz /var/lib/rancher/k3s/agent/images/
sudo cp k3s /usr/local/bin/
sudo chmod +x /usr/local/bin/k3s

# Install
curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_DOWNLOAD=true sh -
```

## Single-Node Installation

### Step 1: Install K3s

```bash
# Install K3s server (includes agent)
curl -sfL https://get.k3s.io | sh -

# Wait for K3s to start
sudo systemctl status k3s
```

### Step 2: Configure kubectl for Your User

```bash
# Create .kube directory
mkdir -p ~/.kube

# Copy kubeconfig
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

# Set ownership
sudo chown $(id -u):$(id -g) ~/.kube/config

# Set KUBECONFIG environment variable
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc
```

### Step 3: Verify Installation

```bash
# Check node status
kubectl get nodes

# Expected output:
# NAME         STATUS   ROLES                  AGE   VERSION
# ubuntu-01    Ready    control-plane,master   1m    v1.29.0+k3s1

# Check system pods
kubectl get pods -A
```

### Step 4: Install kubectl Aliases (Optional)

```bash
# Add helpful aliases
cat >> ~/.bashrc << 'EOF'

# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# Enable kubectl autocompletion
source <(kubectl completion bash)
complete -F __start_kubectl k
EOF

source ~/.bashrc
```

## Multi-Node Cluster

### Server Node (Control Plane)

```bash
# Install K3s server
curl -sfL https://get.k3s.io | sh -

# Get the node token (needed for agents)
sudo cat /var/lib/rancher/k3s/server/node-token
```

### Agent Nodes (Workers)

On each worker node:

```bash
# Set variables
K3S_URL="https://<server-ip>:6443"
K3S_TOKEN="<node-token-from-server>"

# Install K3s agent
curl -sfL https://get.k3s.io | K3S_URL=$K3S_URL K3S_TOKEN=$K3S_TOKEN sh -
```

### Verify Multi-Node Cluster

On the server node:

```bash
kubectl get nodes

# Expected output:
# NAME         STATUS   ROLES                  AGE   VERSION
# server-01    Ready    control-plane,master   5m    v1.29.0+k3s1
# worker-01    Ready    <none>                 2m    v1.29.0+k3s1
# worker-02    Ready    <none>                 1m    v1.29.0+k3s1
```

## Post-Installation Configuration

### Configure Default Storage Class

K3s includes `local-path` storage provisioner:

```bash
# Verify storage class
kubectl get storageclass

# Expected output:
# NAME                   PROVISIONER             AGE
# local-path (default)   rancher.io/local-path   5m
```

### Configure Traefik Ingress

Traefik is installed by default. Verify:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik
```

### Install Helm (Optional but Recommended)

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify
helm version
```

### Install k9s (Optional - Terminal UI)

```bash
# Install k9s for easier cluster management
curl -sS https://webinstall.dev/k9s | bash

# Run k9s
k9s
```

## Verify Installation

### Run Verification Script

```bash
#!/bin/bash
# save as verify-k3s.sh

echo "=== K3s Installation Verification ==="

echo -e "\n1. Checking K3s service..."
sudo systemctl is-active k3s

echo -e "\n2. Checking nodes..."
kubectl get nodes

echo -e "\n3. Checking system pods..."
kubectl get pods -n kube-system

echo -e "\n4. Checking storage class..."
kubectl get storageclass

echo -e "\n5. Checking Traefik ingress..."
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

echo -e "\n6. K3s version..."
k3s --version

echo -e "\n7. kubectl version..."
kubectl version --short

echo -e "\n=== Verification Complete ==="
```

### Test Deployment

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx

# Expose it
kubectl expose deployment nginx --port=80 --type=NodePort

# Get the NodePort
kubectl get svc nginx

# Test access (replace <node-port> with actual port)
curl http://localhost:<node-port>

# Cleanup
kubectl delete deployment nginx
kubectl delete svc nginx
```

## K3s Management

### Service Management

```bash
# Check K3s status
sudo systemctl status k3s

# Start K3s
sudo systemctl start k3s

# Stop K3s
sudo systemctl stop k3s

# Restart K3s
sudo systemctl restart k3s

# Enable K3s on boot
sudo systemctl enable k3s

# View K3s logs
sudo journalctl -u k3s -f
```

### Configuration Files

| File | Purpose |
|------|---------|
| `/etc/rancher/k3s/k3s.yaml` | Kubeconfig file |
| `/var/lib/rancher/k3s/server/` | Server data |
| `/var/lib/rancher/k3s/agent/` | Agent data |
| `/etc/rancher/k3s/config.yaml` | K3s configuration |

### Custom Configuration

Create `/etc/rancher/k3s/config.yaml`:

```yaml
# K3s server configuration
write-kubeconfig-mode: "0644"
tls-san:
  - "pentaho.example.com"
  - "192.168.1.100"
disable:
  - servicelb    # If using external load balancer
# - traefik     # If using different ingress
```

### Upgrade K3s

```bash
# Upgrade to latest stable
curl -sfL https://get.k3s.io | sh -

# Upgrade to specific version
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.29.0+k3s1 sh -
```

## Troubleshooting

### K3s Won't Start

```bash
# Check logs
sudo journalctl -u k3s -f

# Common issues:
# 1. Port 6443 in use
sudo lsof -i :6443

# 2. Swap enabled
sudo swapoff -a

# 3. SELinux issues (if applicable)
sudo setenforce 0
```

### kubectl Not Working

```bash
# Check KUBECONFIG
echo $KUBECONFIG

# Verify config file exists
ls -la ~/.kube/config

# Test with explicit path
kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get nodes
```

### Pods Stuck in Pending

```bash
# Check node resources
kubectl describe nodes

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check storage
kubectl get pvc -A
```

### Network Issues

```bash
# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS resolution
kubectl run tmp --image=busybox --restart=Never --rm -it -- nslookup kubernetes

# Check Flannel
kubectl get pods -n kube-system -l app=flannel
```

### Reset K3s

```bash
# Stop K3s
sudo systemctl stop k3s

# Uninstall
sudo /usr/local/bin/k3s-uninstall.sh

# Clean up data (optional)
sudo rm -rf /var/lib/rancher/k3s

# Reinstall
curl -sfL https://get.k3s.io | sh -
```

## Uninstallation

### Uninstall K3s Server

```bash
# Run uninstall script
sudo /usr/local/bin/k3s-uninstall.sh
```

### Uninstall K3s Agent

```bash
# Run agent uninstall script
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

### Clean Up Completely

```bash
# Remove all K3s data
sudo rm -rf /etc/rancher/k3s
sudo rm -rf /var/lib/rancher/k3s

# Remove kubeconfig
rm -rf ~/.kube

# Remove from bashrc
# (manually remove K3s-related entries)
nano ~/.bashrc
```

## Additional Resources

### Documentation

- [K3s Official Documentation](https://docs.k3s.io/)
- [K3s GitHub Repository](https://github.com/k3s-io/k3s)
- [Rancher Documentation](https://ranchermanager.docs.rancher.com/)

### Community

- [K3s Slack Channel](https://slack.rancher.io/)
- [Rancher Forums](https://forums.rancher.com/)

---

**K3s Version**: Latest stable (v1.29.x)
**Ubuntu Version**: 24.04 LTS
**Last Updated**: 2026-01-19
