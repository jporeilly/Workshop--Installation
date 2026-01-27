#!/bin/bash
# =============================================================================
# Resource Monitoring Script
# =============================================================================
# Monitor resource usage for Pentaho K3s deployment
#
# Displays:
#   - Pod resource usage (CPU, Memory)
#   - Node resource usage
#   - PVC storage usage
#   - Resource limits and requests
#   - Container restart counts
#
# Usage: ./scripts/monitor-resources.sh
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="pentaho"

echo -e "${BLUE}=============================================="
echo -e "  Resource Monitoring - Pentaho K3s"
echo -e "==============================================${NC}\n"

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}Namespace '$NAMESPACE' not found${NC}"
    exit 1
fi

# Pod Resource Usage
echo -e "${YELLOW}=== Pod Resource Usage ===${NC}"
if kubectl top pods -n $NAMESPACE 2>/dev/null; then
    echo ""
else
    echo -e "${YELLOW}Metrics server not available - install with:${NC}"
    echo "  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    echo ""
fi

# Node Resource Usage
echo -e "${YELLOW}=== Node Resource Usage ===${NC}"
kubectl top nodes 2>/dev/null || echo -e "${YELLOW}Metrics server not available${NC}"
echo ""

# PVC Storage Usage
echo -e "${YELLOW}=== Persistent Volume Claims ===${NC}"
kubectl get pvc -n $NAMESPACE -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.phase,\
CAPACITY:.status.capacity.storage,\
STORAGECLASS:.spec.storageClassName,\
AGE:.metadata.creationTimestamp
echo ""

# Resource Limits and Requests
echo -e "${YELLOW}=== Resource Limits and Requests ===${NC}"
kubectl get pods -n $NAMESPACE -o custom-columns=\
POD:.metadata.name,\
"MEMORY REQUEST":.spec.containers[0].resources.requests.memory,\
"MEMORY LIMIT":.spec.containers[0].resources.limits.memory,\
"CPU REQUEST":.spec.containers[0].resources.requests.cpu,\
"CPU LIMIT":.spec.containers[0].resources.limits.cpu
echo ""

# Container Status
echo -e "${YELLOW}=== Container Status ===${NC}"
kubectl get pods -n $NAMESPACE -o custom-columns=\
POD:.metadata.name,\
READY:.status.containerStatuses[0].ready,\
RESTARTS:.status.containerStatuses[0].restartCount,\
STATUS:.status.phase,\
NODE:.spec.nodeName
echo ""

# Recent Resource Events
echo -e "${YELLOW}=== Recent Resource-Related Events ===${NC}"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | \
    grep -i "OOM\|memory\|CPU\|limit\|evict\|fail" | tail -10 || \
    echo "No resource-related events found"
echo ""

# Storage Usage (if PVCs are mounted)
echo -e "${YELLOW}=== Storage Usage (Inside Containers) ===${NC}"

# Check PostgreSQL storage
POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ ! -z "$POSTGRES_POD" ]; then
    echo -e "${BLUE}PostgreSQL:${NC}"
    kubectl exec -n $NAMESPACE $POSTGRES_POD -- df -h /var/lib/postgresql/data 2>/dev/null | tail -1 || \
        echo "  Unable to check storage"
else
    echo -e "${YELLOW}PostgreSQL pod not found${NC}"
fi
echo ""

# Memory Usage Summary
echo -e "${YELLOW}=== Memory Usage Summary ===${NC}"
if command -v bc &> /dev/null && kubectl top pods -n $NAMESPACE &> /dev/null; then
    TOTAL_MEMORY=$(kubectl top pods -n $NAMESPACE --no-headers | awk '{sum+=$3} END {print sum}')
    echo -e "Total Memory Used: ${GREEN}${TOTAL_MEMORY}Mi${NC}"
else
    echo -e "${YELLOW}Unable to calculate (requires bc and metrics-server)${NC}"
fi
echo ""

# Recommendations
echo -e "${YELLOW}=== Recommendations ===${NC}"

# Check for high memory usage
if kubectl top pods -n $NAMESPACE 2>/dev/null | awk 'NR>1 {if (int($3) > 4096) print $1, $3}' | grep -q .; then
    echo -e "${RED}⚠ High memory usage detected${NC}"
    echo "  Consider increasing memory limits in deployment.yaml"
else
    echo -e "${GREEN}✓ Memory usage within normal range${NC}"
fi

# Check for restarts
RESTART_COUNT=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' | awk '{for(i=1;i<=NF;i++) sum+=$i} END {print sum}')
if [ "$RESTART_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠ Container restarts detected: $RESTART_COUNT${NC}"
    echo "  Check logs: kubectl logs -n pentaho <pod-name> --previous"
else
    echo -e "${GREEN}✓ No container restarts${NC}"
fi

echo ""
echo -e "${BLUE}=============================================="
echo -e "  End of Resource Report"
echo -e "==============================================${NC}\n"

# Quick summary
echo -e "Quick commands:"
echo -e "  ${BLUE}kubectl top pods -n $NAMESPACE${NC}         # Live pod metrics"
echo -e "  ${BLUE}kubectl describe pod -n $NAMESPACE <pod>${NC}  # Detailed pod info"
echo -e "  ${BLUE}make logs${NC}                            # View Pentaho logs"
echo ""
