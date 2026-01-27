# =============================================================================
# Pentaho K3s Deployment Makefile
# =============================================================================
# Simplifies common deployment and management tasks
#
# Prerequisites:
#   - Docker installed
#   - K3s installed and running
#   - kubectl configured
#   - Secrets file at manifests/secrets/secrets.yaml
#
# Usage: make <target>
# =============================================================================

.DEFAULT_GOAL := help
.PHONY: help build import deploy destroy clean logs logs-postgres status health \
        backup restore validate monitor monitor-postgres port-forward test-local

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# Configuration
IMAGE_NAME := pentaho/pentaho-server
IMAGE_TAG := 11.0.0.0-237
NAMESPACE := pentaho
SUDO_PASSWORD := password

##@ General

help: ## Display this help message
	@echo ""
	@echo -e "$(BLUE)Pentaho K3s Deployment Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(YELLOW)<target>$(NC)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""

##@ Build & Deploy

build: ## Build Pentaho Docker image
	@echo -e "$(BLUE)Building Pentaho Docker image...$(NC)"
	cd docker-build && ./build.sh

import: ## Import Docker image to K3s
	@echo -e "$(BLUE)Importing image to K3s...$(NC)"
	@docker save $(IMAGE_NAME):$(IMAGE_TAG) -o /tmp/pentaho.tar
	@echo "$(SUDO_PASSWORD)" | sudo -S k3s ctr images import /tmp/pentaho.tar
	@rm /tmp/pentaho.tar
	@echo -e "$(GREEN)✓ Image imported successfully$(NC)"

deploy: ## Deploy to K3s (skip image import)
	@echo -e "$(BLUE)Deploying to K3s...$(NC)"
	./deploy.sh --skip-import

full-deploy: build import deploy ## Build, import, and deploy (complete workflow)
	@echo -e "$(GREEN)✓ Full deployment complete!$(NC)"

destroy: ## Remove Pentaho deployment from K3s
	@echo -e "$(YELLOW)Removing Pentaho deployment...$(NC)"
	./destroy.sh

clean: destroy ## Alias for destroy
	@echo -e "$(GREEN)✓ Cleanup complete$(NC)"

##@ Monitoring

status: ## Show deployment status
	@echo -e "$(BLUE)Deployment Status:$(NC)"
	@kubectl get all -n $(NAMESPACE)

health: ## Run health check
	@./scripts/health-check.sh

logs: ## Follow Pentaho Server logs
	kubectl logs -f -n $(NAMESPACE) deployment/pentaho-server

logs-postgres: ## Follow PostgreSQL logs
	kubectl logs -f -n $(NAMESPACE) deployment/postgres

monitor: ## Monitor resource usage
	@./scripts/monitor-resources.sh

monitor-postgres: ## Monitor PostgreSQL databases
	@./scripts/monitor-postgres.sh

validate: ## Validate deployment configuration
	@./scripts/validate-deployment.sh

##@ Database Operations

backup: ## Backup PostgreSQL databases
	@./scripts/backup-postgres.sh

restore: ## Restore PostgreSQL databases (requires BACKUP_FILE=<file>)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo -e "$(RED)Error: BACKUP_FILE not specified$(NC)"; \
		echo -e "Usage: make restore BACKUP_FILE=backup-2026-01-26.sql"; \
		exit 1; \
	fi
	@./scripts/restore-postgres.sh $(BACKUP_FILE)

db-shell: ## Connect to PostgreSQL shell
	kubectl exec -it -n $(NAMESPACE) deployment/postgres -- psql -U postgres

##@ Access

port-forward: ## Port-forward Pentaho to localhost:8080
	@echo -e "$(BLUE)Port-forwarding Pentaho Server to localhost:8080...$(NC)"
	@echo -e "$(GREEN)Access at: http://localhost:8080/pentaho$(NC)"
	@echo -e "$(YELLOW)Press Ctrl+C to stop$(NC)"
	kubectl port-forward -n $(NAMESPACE) svc/pentaho-server 8080:8080

open: port-forward ## Alias for port-forward

##@ Testing

test-local: ## Test Docker image locally with Docker Compose
	@echo -e "$(BLUE)Starting local test environment...$(NC)"
	cd docker-build && docker compose -f test-compose.yml up

test-local-down: ## Stop local test environment
	@echo -e "$(YELLOW)Stopping local test environment...$(NC)"
	cd docker-build && docker compose -f test-compose.yml down -v

##@ Development

rebuild: ## Rebuild and redeploy (for development)
	@echo -e "$(BLUE)Rebuilding and redeploying...$(NC)"
	$(MAKE) build
	$(MAKE) import
	kubectl delete pod -n $(NAMESPACE) -l app=pentaho-server
	@echo -e "$(GREEN)✓ Rebuild complete - waiting for new pod to start...$(NC)"
	kubectl wait --for=condition=ready pod -l app=pentaho-server -n $(NAMESPACE) --timeout=300s

shell: ## Open shell in Pentaho Server pod
	kubectl exec -it -n $(NAMESPACE) deployment/pentaho-server -- /bin/bash

shell-postgres: ## Open shell in PostgreSQL pod
	kubectl exec -it -n $(NAMESPACE) deployment/postgres -- /bin/bash

describe-pentaho: ## Describe Pentaho Server pod
	kubectl describe pod -n $(NAMESPACE) -l app=pentaho-server

describe-postgres: ## Describe PostgreSQL pod
	kubectl describe pod -n $(NAMESPACE) -l app=postgres

events: ## Show recent events in pentaho namespace
	kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp'

##@ Quick Commands

quick-status: ## Quick one-line status check
	@kubectl get pods -n $(NAMESPACE) -o wide

restart-pentaho: ## Restart Pentaho Server pod
	kubectl delete pod -n $(NAMESPACE) -l app=pentaho-server

restart-postgres: ## Restart PostgreSQL pod
	kubectl delete pod -n $(NAMESPACE) -l app=postgres

##@ Information

info: ## Show deployment information
	@echo -e "$(BLUE)Pentaho K3s Deployment Information$(NC)"
	@echo ""
	@echo -e "Image:      $(GREEN)$(IMAGE_NAME):$(IMAGE_TAG)$(NC)"
	@echo -e "Namespace:  $(GREEN)$(NAMESPACE)$(NC)"
	@echo ""
	@echo -e "$(YELLOW)Quick Start:$(NC)"
	@echo "  make full-deploy   # Complete deployment"
	@echo "  make health        # Check health"
	@echo "  make port-forward  # Access Pentaho"
	@echo ""
	@echo -e "$(YELLOW)Common Commands:$(NC)"
	@echo "  make status        # Show deployment status"
	@echo "  make logs          # View logs"
	@echo "  make backup        # Backup databases"
	@echo ""

version: ## Show versions
	@echo -e "$(BLUE)Version Information:$(NC)"
	@echo -n "Docker:     " && docker --version
	@echo -n "kubectl:    " && kubectl version --client --short 2>/dev/null || kubectl version --client
	@echo -n "K3s:        " && k3s --version | head -1
	@echo ""
