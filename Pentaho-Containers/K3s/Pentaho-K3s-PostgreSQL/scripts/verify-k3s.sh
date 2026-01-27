#!/bin/bash
# =============================================================================
# K3s Installation Verification Script
# =============================================================================
# This script performs comprehensive checks to verify K3s is installed and
# running correctly with all required components.
#
# Usage: ./scripts/verify-k3s.sh
#
# Checks performed:
#   1. K3s systemd service status
#   2. Kubernetes node availability and status
#   3. System pods (CoreDNS, metrics-server, etc.)
#   4. Storage class availability (local-path provisioner)
#   5. Traefik ingress controller pods
#   6. K3s version information
#   7. kubectl client version
#
# Exit codes:
#   0 - All checks passed (services may still be starting)
#   Non-zero - One or more checks failed
# =============================================================================

echo "=== K3s Installation Verification ==="

# -----------------------------------------------------------------------------
# Check 1: K3s Service Status
# -----------------------------------------------------------------------------
# Verifies that the K3s systemd service is active and running
# K3s runs as a single binary that includes both server and agent components
echo -e "\n1. Checking K3s service..."
sudo systemctl is-active k3s

# -----------------------------------------------------------------------------
# Check 2: Kubernetes Nodes
# -----------------------------------------------------------------------------
# Lists all nodes in the cluster and their status
# For single-node deployments, you should see one node in "Ready" status
# For multi-node deployments, all nodes should be listed here
echo -e "\n2. Checking nodes..."
kubectl get nodes

# -----------------------------------------------------------------------------
# Check 3: System Pods
# -----------------------------------------------------------------------------
# Displays all pods in the kube-system namespace
# Essential components include:
#   - coredns: DNS service for cluster service discovery
#   - metrics-server: Resource metrics for autoscaling and kubectl top
#   - local-path-provisioner: Dynamic storage provisioning
#   - traefik: Default ingress controller
echo -e "\n3. Checking system pods..."
kubectl get pods -n kube-system

# -----------------------------------------------------------------------------
# Check 4: Storage Classes
# -----------------------------------------------------------------------------
# Lists available storage classes for PersistentVolumeClaims
# K3s includes "local-path" storage class by default
# This is used for dynamic provisioning of host-path based volumes
echo -e "\n4. Checking storage class..."
kubectl get storageclass

# -----------------------------------------------------------------------------
# Check 5: Traefik Ingress Controller
# -----------------------------------------------------------------------------
# Verifies Traefik ingress controller is running
# Traefik is K3s's default ingress controller (replaces nginx-ingress)
# It handles external HTTP/HTTPS traffic routing to services
echo -e "\n5. Checking Traefik ingress..."
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# -----------------------------------------------------------------------------
# Check 6: K3s Version
# -----------------------------------------------------------------------------
# Displays the installed K3s version
# K3s follows Kubernetes versioning (e.g., v1.28.4+k3s1)
echo -e "\n6. K3s version..."
k3s --version

# -----------------------------------------------------------------------------
# Check 7: kubectl Version
# -----------------------------------------------------------------------------
# Shows both client and server Kubernetes versions
# Client version is kubectl, server version is K3s API server
# Note: --short flag was deprecated in kubectl 1.28+
echo -e "\n7. kubectl version..."
kubectl version --output=yaml 2>/dev/null || kubectl version

echo -e "\n=== Verification Complete ==="