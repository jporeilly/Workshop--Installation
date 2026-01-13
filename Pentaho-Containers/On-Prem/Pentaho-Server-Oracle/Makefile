# =============================================================================
# Pentaho Server 11 Docker Deployment (Oracle Repository)
# Makefile for common operations
# =============================================================================

# Load environment variables from .env if it exists
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Docker Compose command
COMPOSE = docker compose

# Colors for output
GREEN  = \033[0;32m
YELLOW = \033[1;33m
BLUE   = \033[0;34m
RED    = \033[0;31m
NC     = \033[0m

# Default target
.DEFAULT_GOAL := help

# =============================================================================
# Deployment Targets
# =============================================================================

.PHONY: deploy
deploy: ## Run the automated deployment script
	@./deploy.sh

.PHONY: up
up: ## Start all services
	@echo "$(BLUE)Starting all services...$(NC)"
	@$(COMPOSE) up -d
	@echo "$(GREEN)Services started$(NC)"
	@$(MAKE) urls

.PHONY: down
down: ## Stop and remove all containers
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@$(COMPOSE) down
	@echo "$(GREEN)Services stopped$(NC)"

.PHONY: restart
restart: ## Restart all services
	@echo "$(BLUE)Restarting all services...$(NC)"
	@$(COMPOSE) restart
	@echo "$(GREEN)Services restarted$(NC)"

.PHONY: stop
stop: ## Stop all services (keep containers)
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@$(COMPOSE) stop
	@echo "$(GREEN)Services stopped$(NC)"

.PHONY: start
start: ## Start stopped services
	@echo "$(BLUE)Starting services...$(NC)"
	@$(COMPOSE) start
	@echo "$(GREEN)Services started$(NC)"

# =============================================================================
# Build Targets
# =============================================================================

.PHONY: build
build: ## Build Pentaho Server image
	@echo "$(BLUE)Building Pentaho Server image...$(NC)"
	@$(COMPOSE) build pentaho-server
	@echo "$(GREEN)Build complete$(NC)"

.PHONY: rebuild
rebuild: ## Rebuild Pentaho Server image (no cache)
	@echo "$(BLUE)Rebuilding Pentaho Server image (no cache)...$(NC)"
	@$(COMPOSE) build --no-cache pentaho-server
	@echo "$(GREEN)Rebuild complete$(NC)"

.PHONY: pull
pull: ## Pull latest Oracle image
	@echo "$(BLUE)Pulling Oracle image...$(NC)"
	@$(COMPOSE) pull oracle
	@echo "$(GREEN)Pull complete$(NC)"

# =============================================================================
# Log Targets
# =============================================================================

.PHONY: logs
logs: ## Show logs for all services
	@$(COMPOSE) logs

.PHONY: logs-follow
logs-follow: ## Follow logs for all services
	@$(COMPOSE) logs -f

.PHONY: logs-pentaho
logs-pentaho: ## Show Pentaho Server logs
	@$(COMPOSE) logs pentaho-server

.PHONY: logs-oracle
logs-oracle: ## Show Oracle logs
	@$(COMPOSE) logs oracle

.PHONY: logs-follow-pentaho
logs-follow-pentaho: ## Follow Pentaho Server logs
	@$(COMPOSE) logs -f pentaho-server

# =============================================================================
# Backup and Restore Targets
# =============================================================================

.PHONY: backup
backup: ## Backup Oracle databases
	@echo "$(BLUE)Backing up Oracle databases...$(NC)"
	@./scripts/backup-oracle.sh
	@echo "$(GREEN)Backup complete$(NC)"

.PHONY: restore
restore: ## Restore Oracle databases (usage: make restore BACKUP=filename)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)Error: Please specify BACKUP file$(NC)"; \
		echo "Usage: make restore BACKUP=backup_file.dmp"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring Oracle databases from $(BACKUP)...$(NC)"
	@./scripts/restore-oracle.sh $(BACKUP)
	@echo "$(GREEN)Restore complete$(NC)"

.PHONY: list-backups
list-backups: ## List available backups
	@echo "$(BLUE)Available backups:$(NC)"
	@ls -lh backups/*.dmp 2>/dev/null || echo "No backups found"

# =============================================================================
# Maintenance Targets
# =============================================================================

.PHONY: clean
clean: down ## Stop services and remove volumes
	@echo "$(YELLOW)Removing volumes...$(NC)"
	@$(COMPOSE) down -v
	@echo "$(GREEN)Cleanup complete$(NC)"

.PHONY: clean-all
clean-all: clean ## Remove everything including images
	@echo "$(YELLOW)Removing images...$(NC)"
	@docker rmi $$(docker images -q pentaho/pentaho-server-oracle) 2>/dev/null || true
	@echo "$(GREEN)Full cleanup complete$(NC)"

.PHONY: prune
prune: ## Remove unused Docker resources
	@echo "$(YELLOW)Pruning unused Docker resources...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)Prune complete$(NC)"

.PHONY: validate
validate: ## Run deployment validation script
	@./scripts/validate-deployment.sh

# =============================================================================
# Development Targets
# =============================================================================

.PHONY: shell
shell: ## Open shell in Pentaho container
	@$(COMPOSE) exec pentaho-server /bin/bash

.PHONY: oracle-shell
oracle-shell: ## Open SQL*Plus in Oracle container
	@$(COMPOSE) exec oracle sqlplus / as sysdba

.PHONY: status
status: ## Show status of all services
	@echo "$(BLUE)Service Status:$(NC)"
	@$(COMPOSE) ps

.PHONY: stats
stats: ## Show resource usage statistics
	@echo "$(BLUE)Resource Usage:$(NC)"
	@docker stats --no-stream pentaho-server pentaho-oracle 2>/dev/null || echo "$(YELLOW)Containers not running$(NC)"

# =============================================================================
# Information Targets
# =============================================================================

.PHONY: urls
urls: ## Display service URLs
	@echo ""
	@echo "$(BLUE)Service URLs:$(NC)"
	@echo "  Pentaho Server: $(YELLOW)http://localhost:$${PENTAHO_HTTP_PORT:-8090}/pentaho$(NC)"
	@echo ""
	@echo "$(BLUE)Credentials:$(NC)"
	@echo "  Pentaho: admin / password"
	@echo "  Oracle:  jcr_user, pentaho_user, hibuser / password"
	@echo ""

.PHONY: version
version: ## Show version information
	@echo "$(BLUE)Version Information:$(NC)"
	@echo "  Pentaho Version: $${PENTAHO_VERSION:-11.0.0.0-237}"
	@echo "  Docker: $$(docker --version)"
	@echo "  Docker Compose: $$(docker compose version)"

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo "$(BLUE)Pentaho Server 11 - Oracle Repository$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC) make [target]"
	@echo ""
	@echo "$(YELLOW)Targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2}'
	@echo ""
