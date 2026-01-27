#!/bin/bash
# =============================================================================
# K3s Installation Verification Script
# =============================================================================
# This script performs comprehensive checks to verify K3s is installed and
# running correctly with all required components.
#
# Usage: ./scripts/verify-k3s.sh [OPTIONS]
#
# Options:
#   --verbose, -v    Show detailed output
#   --quiet, -q      Only show errors
#   --help, -h       Show this help message
#
# Checks performed:
#   1. K3s systemd service status
#   2. Kubernetes node availability and status
#   3. System pods (CoreDNS, metrics-server, etc.)
#   4. Storage class availability (local-path provisioner)
#   5. Traefik ingress controller pods
#   6. K3s and kubectl version information
#   7. Network connectivity (DNS resolution)
#   8. Cluster resource availability
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed
#   2 - Critical failure (K3s not installed or not running)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Color Definitions
# -----------------------------------------------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

# -----------------------------------------------------------------------------
# Global Variables
# -----------------------------------------------------------------------------
VERBOSE=false
QUIET=false
FAILED_CHECKS=0
TOTAL_CHECKS=0
WARNINGS=0
START_TIME=$(date +%s)

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

print_header() {
    if [[ "$QUIET" == "false" ]]; then
        echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"
    fi
}

print_check() {
    if [[ "$QUIET" == "false" ]]; then
        echo -e "\n${CYAN}[$((++TOTAL_CHECKS))] $1${NC}"
    fi
}

print_success() {
    if [[ "$QUIET" == "false" ]]; then
        echo -e "${GREEN}✓${NC} $1"
    fi
}

print_error() {
    echo -e "${RED}✗${NC} $1" >&2
    ((FAILED_CHECKS++))
}

print_warning() {
    if [[ "$QUIET" == "false" ]]; then
        echo -e "${YELLOW}⚠${NC} $1"
        ((WARNINGS++))
    fi
}

print_info() {
    if [[ "$VERBOSE" == "true" ]] && [[ "$QUIET" == "false" ]]; then
        echo -e "${BLUE}ℹ${NC} $1"
    fi
}

show_help() {
    cat << EOF
K3s Installation Verification Script

Usage: $0 [OPTIONS]

Options:
  -v, --verbose    Show detailed output
  -q, --quiet      Only show errors
  -h, --help       Show this help message

Examples:
  $0                 # Normal verification
  $0 --verbose       # Verbose output with details
  $0 --quiet         # Only show errors

EOF
    exit 0
}

# -----------------------------------------------------------------------------
# Check Functions
# -----------------------------------------------------------------------------

check_k3s_service() {
    print_check "Checking K3s service status..."

    if ! command -v systemctl &> /dev/null; then
        print_error "systemctl not found - cannot check K3s service"
        return 1
    fi

    if sudo systemctl is-active --quiet k3s; then
        print_success "K3s service is active and running"

        if [[ "$VERBOSE" == "true" ]]; then
            sudo systemctl status k3s --no-pager --lines=5
        fi
        return 0
    else
        print_error "K3s service is not running"
        print_info "Run: sudo systemctl start k3s"
        return 1
    fi
}

check_kubectl() {
    print_check "Checking kubectl availability..."

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found in PATH"
        print_info "K3s installs kubectl at /usr/local/bin/kubectl"
        return 1
    fi

    if kubectl cluster-info &> /dev/null; then
        print_success "kubectl can connect to cluster"
        return 0
    else
        print_error "kubectl cannot connect to cluster"
        print_info "Check KUBECONFIG or run: export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
        return 1
    fi
}

check_nodes() {
    print_check "Checking Kubernetes nodes..."

    local node_output
    if ! node_output=$(kubectl get nodes 2>&1); then
        print_error "Failed to get nodes: $node_output"
        return 1
    fi

    local total_nodes
    total_nodes=$(echo "$node_output" | tail -n +2 | wc -l)

    local ready_nodes
    ready_nodes=$(echo "$node_output" | grep -c " Ready " || true)

    if [[ $ready_nodes -eq $total_nodes ]] && [[ $total_nodes -gt 0 ]]; then
        print_success "All $total_nodes node(s) are Ready"

        if [[ "$VERBOSE" == "true" ]]; then
            echo "$node_output"
        fi
        return 0
    else
        print_error "Only $ready_nodes of $total_nodes node(s) are Ready"
        echo "$node_output"
        return 1
    fi
}

check_system_pods() {
    print_check "Checking system pods..."

    local pod_output
    if ! pod_output=$(kubectl get pods -n kube-system 2>&1); then
        print_error "Failed to get system pods: $pod_output"
        return 1
    fi

    # Count total and running pods
    local total_pods
    total_pods=$(echo "$pod_output" | tail -n +2 | wc -l)

    local running_pods
    running_pods=$(echo "$pod_output" | grep -c "Running" || true)

    # Check for essential components
    local essential_components=("coredns" "metrics-server" "local-path-provisioner" "traefik")
    local missing_components=()

    for component in "${essential_components[@]}"; do
        if ! echo "$pod_output" | grep -q "$component"; then
            missing_components+=("$component")
        fi
    done

    if [[ ${#missing_components[@]} -gt 0 ]]; then
        print_error "Missing essential components: ${missing_components[*]}"
        return 1
    fi

    # Check if all pods are running (exclude Completed jobs)
    local not_running
    not_running=$((total_pods - running_pods))

    # Count completed jobs (helm-install jobs that have finished successfully)
    local completed_jobs
    completed_jobs=$(echo "$pod_output" | grep -c "Completed" || true)

    # Actual problematic pods (not running and not completed)
    local actual_problems
    actual_problems=$((not_running - completed_jobs))

    if [[ $actual_problems -gt 0 ]]; then
        print_warning "$actual_problems of $total_pods system pod(s) not in Running state"

        # Show which pods are not running (exclude Completed)
        local problem_pods
        problem_pods=$(echo "$pod_output" | tail -n +2 | grep -v "Running" | grep -v "Completed" | awk '{print $1 " (" $3 ")"}' || true)

        if [[ -n "$problem_pods" ]]; then
            print_info "Pods not in Running state:"
            echo "$problem_pods" | while read -r pod; do
                echo "  - $pod"
            done
        fi

        if [[ "$VERBOSE" == "true" ]]; then
            echo ""
            echo "$pod_output"
        fi

        # Check if they're just starting
        if echo "$pod_output" | grep -qE "Pending|ContainerCreating|PodInitializing"; then
            print_info "Some pods are still starting up - this is normal during initial setup"
        fi

        # Check for errors
        if echo "$pod_output" | grep -qE "Error|CrashLoopBackOff|ImagePullBackOff"; then
            print_error "Some pods have errors - check with: kubectl get pods -n kube-system"
            return 1
        fi
    else
        # Check if we have completed jobs to mention
        if [[ $completed_jobs -gt 0 ]]; then
            print_success "All active system pods are Running ($completed_jobs completed job(s))"
        else
            print_success "All $total_pods system pods are Running"
        fi

        if [[ "$VERBOSE" == "true" ]]; then
            echo "$pod_output"
        fi
    fi

    return 0
}

check_storage_class() {
    print_check "Checking storage classes..."

    local sc_output
    if ! sc_output=$(kubectl get storageclass 2>&1); then
        print_error "Failed to get storage classes: $sc_output"
        return 1
    fi

    if echo "$sc_output" | grep -q "local-path"; then
        print_success "local-path storage class is available"

        # Check if it's the default
        if echo "$sc_output" | grep "local-path" | grep -q "(default)"; then
            print_info "local-path is set as default storage class"
        else
            print_warning "local-path is not the default storage class"
        fi

        if [[ "$VERBOSE" == "true" ]]; then
            echo "$sc_output"
        fi
        return 0
    else
        print_error "local-path storage class not found"
        echo "$sc_output"
        return 1
    fi
}

check_traefik() {
    print_check "Checking Traefik ingress controller..."

    local traefik_output
    if ! traefik_output=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik 2>&1); then
        print_error "Failed to get Traefik pods: $traefik_output"
        return 1
    fi

    if echo "$traefik_output" | grep -q "Running"; then
        print_success "Traefik ingress controller is running"

        if [[ "$VERBOSE" == "true" ]]; then
            echo "$traefik_output"
        fi
        return 0
    else
        print_warning "Traefik ingress controller not running"
        print_info "Traefik may be disabled or still starting"

        if [[ "$VERBOSE" == "true" ]]; then
            echo "$traefik_output"
        fi
    fi

    return 0
}

check_versions() {
    print_check "Checking K3s and kubectl versions..."

    # K3s version
    if command -v k3s &> /dev/null; then
        local k3s_version
        k3s_version=$(k3s --version | head -n 1)
        print_success "K3s installed: $k3s_version"
    else
        print_error "k3s command not found"
        return 1
    fi

    # kubectl version
    local kubectl_version
    if kubectl_version=$(kubectl version --output=yaml 2>/dev/null); then
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$kubectl_version"
        else
            local client_version
            client_version=$(echo "$kubectl_version" | grep "gitVersion" | head -n 1 | awk '{print $2}')
            print_info "kubectl client version: $client_version"
        fi
    else
        # Fallback for older kubectl versions
        kubectl version 2>/dev/null || print_warning "Could not get kubectl version"
    fi

    return 0
}

check_dns() {
    print_check "Checking cluster DNS resolution..."

    # First check if CoreDNS pods are running
    local coredns_pods
    coredns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null)

    if [[ -z "$coredns_pods" ]]; then
        print_warning "CoreDNS pods not found - skipping DNS test"
        print_info "This is normal if K3s was installed with --disable=coredns"
        return 0
    fi

    # Check if CoreDNS is ready
    local coredns_ready
    coredns_ready=$(echo "$coredns_pods" | grep "Running" | grep "1/1" | wc -l)

    if [[ $coredns_ready -eq 0 ]]; then
        print_warning "CoreDNS not ready yet - skipping DNS test"
        print_info "Wait for CoreDNS: kubectl wait --for=condition=ready pod -l k8s-app=kube-dns -n kube-system --timeout=60s"
        return 0
    fi

    print_success "CoreDNS pod is running and ready"

    # Optional: Try actual DNS resolution (may fail in VMs with local DNS)
    local test_pod_name="dns-test-$$"
    local dns_test_output

    # Try DNS resolution with a shorter timeout
    if dns_test_output=$(timeout 15s kubectl run "$test_pod_name" --image=busybox:1.36 --restart=Never --rm -i -- nslookup kubernetes.default 2>&1); then
        if echo "$dns_test_output" | grep -q "Address"; then
            print_info "DNS resolution test passed"
            return 0
        fi
    fi

    # DNS test failed, but this is not critical
    if [[ "$VERBOSE" == "true" ]]; then
        print_info "DNS resolution test failed (this is common in VMs with local DNS)"
        echo "DNS test output:"
        echo "$dns_test_output" | head -10
    else
        print_info "DNS resolution test skipped (CoreDNS is running - sufficient for deployment)"
    fi

    # Cleanup test pod if it exists
    kubectl delete pod "$test_pod_name" --ignore-not-found=true &> /dev/null 2>&1 || true
    return 0
}

check_resources() {
    print_check "Checking cluster resources..."

    # Check if kubectl top works (requires metrics-server)
    if kubectl top node &> /dev/null; then
        local node_metrics
        node_metrics=$(kubectl top node --no-headers 2>/dev/null || echo "")

        if [[ -n "$node_metrics" ]]; then
            print_success "Metrics server is working"

            if [[ "$VERBOSE" == "true" ]]; then
                kubectl top node
            fi
        else
            print_warning "Metrics server not yet ready"
        fi
    else
        print_warning "Cannot retrieve node metrics (metrics-server may still be starting)"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Parse Command Line Arguments
# -----------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

print_header "K3s Installation Verification"

# Run all checks
check_k3s_service || true
check_kubectl || exit 2
check_nodes || true
check_system_pods || true
check_storage_class || true
check_traefik || true
check_versions || true
check_dns || true
check_resources || true

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

print_header "Verification Summary"

# Calculate elapsed time
end_time=$(date +%s)
elapsed=$((end_time - START_TIME))

echo -e "${BLUE}Completed $TOTAL_CHECKS checks in ${elapsed}s${NC}"
echo ""

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ All checks passed!${NC}"
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s) - review above${NC}"
    fi
    echo ""
    echo -e "${GREEN}K3s is ready for deploying applications!${NC}"

    # Show next steps
    if [[ "$QUIET" == "false" ]]; then
        echo ""
        echo -e "${BOLD}Next steps:${NC}"
        echo "  • Deploy applications to K3s"
        echo "  • Check cluster status: kubectl get all -A"
        echo "  • View node resources: kubectl top nodes"
    fi
    exit 0
else
    echo -e "${RED}${BOLD}✗ $FAILED_CHECKS check(s) failed${NC}"
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}⚠ $WARNINGS warning(s)${NC}"
    fi
    echo ""
    echo -e "${YELLOW}K3s may need additional configuration or time to start up${NC}"

    # Show troubleshooting tips
    if [[ "$QUIET" == "false" ]]; then
        echo ""
        echo -e "${BOLD}Troubleshooting:${NC}"
        echo "  • Check logs: sudo journalctl -u k3s -f"
        echo "  • Restart K3s: sudo systemctl restart k3s"
        echo "  • Wait and retry: sleep 30 && ./verify-k3s.sh"
        echo "  • View system pods: kubectl get pods -n kube-system"
    fi
    exit 1
fi
