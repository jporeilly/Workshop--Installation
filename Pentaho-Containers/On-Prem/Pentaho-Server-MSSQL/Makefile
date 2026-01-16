.DEFAULT_GOAL := help
.PHONY: all help deploy up down restart stop start build rebuild pull logs logs-follow logs-pentaho logs-mssql backup restore list-backups clean clean-all prune validate shell mssql-shell status ps stats urls version

# Load environment variables if .env exists
-include .env
export

# Docker Compose command
COMPOSE := docker compose
PROJECT_NAME := pentaho-server-mssql

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
RED    := \033[0;31m
NC     := \033[0m # No Color

##@ Deployment

deploy: ## Run automated deployment script
	@echo "$(BLUE)→ Running automated deployment...$(NC)"
	@./deploy.sh

up: ## Start all services
	@echo "$(BLUE)→ Starting services...$(NC)"
	@$(COMPOSE) up -d
	@echo "$(GREEN)✓ Services started successfully$(NC)"

down: ## Stop all services
	@echo "$(YELLOW)→ Stopping services...$(NC)"
	@$(COMPOSE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart all services
	@echo "$(BLUE)→ Restarting services...$(NC)"
	@$(COMPOSE) restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

stop: ## Stop containers without removing
	@echo "$(YELLOW)→ Stopping containers...$(NC)"
	@$(COMPOSE) stop
	@echo "$(GREEN)✓ Containers stopped$(NC)"

start: ## Start stopped containers
	@echo "$(BLUE)→ Starting containers...$(NC)"
	@$(COMPOSE) start
	@echo "$(GREEN)✓ Containers started$(NC)"

##@ Build

build: ## Build Pentaho Server image
	@echo "$(BLUE)→ Building Pentaho Server image...$(NC)"
	@$(COMPOSE) build pentaho-server
	@echo "$(GREEN)✓ Build complete$(NC)"

rebuild: ## Rebuild image with --no-cache
	@echo "$(BLUE)→ Rebuilding from scratch...$(NC)"
	@$(COMPOSE) build --no-cache pentaho-server
	@echo "$(GREEN)✓ Rebuild complete$(NC)"

pull: ## Pull latest base images
	@echo "$(BLUE)→ Pulling latest images...$(NC)"
	@$(COMPOSE) pull mssql
	@echo "$(GREEN)✓ Images pulled$(NC)"

##@ Logs

logs: ## View all logs (last 100 lines)
	@$(COMPOSE) logs --tail=100

logs-follow: ## Follow all logs in real-time
	@$(COMPOSE) logs -f

logs-pentaho: ## View Pentaho Server logs only
	@$(COMPOSE) logs --tail=100 -f pentaho-server

logs-mssql: ## View SQL Server logs only
	@$(COMPOSE) logs --tail=100 -f mssql

##@ Backup & Restore

backup: ## Create SQL Server backup
	@echo "$(BLUE)→ Creating backup...$(NC)"
	@./scripts/backup-mssql.sh

restore: ## Restore from backup (use: make restore BACKUP=file.bak)
	@if [ -z "$(BACKUP)" ]; then \
		echo "$(RED)✗ Error: BACKUP variable required$(NC)"; \
		echo "  Usage: make restore BACKUP=backups/pentaho-mssql-backup-YYYYMMDD-HHMMSS.bak"; \
		exit 1; \
	fi
	@echo "$(YELLOW)→ Restoring from $(BACKUP)...$(NC)"
	@./scripts/restore-mssql.sh $(BACKUP)

list-backups: ## List available backup files
	@echo "$(BLUE)Available backups:$(NC)"
	@ls -lh backups/*.bak 2>/dev/null || echo "$(YELLOW)No backups found$(NC)"

##@ Maintenance

clean: ## Stop and remove containers (keep volumes)
	@echo "$(YELLOW)→ Cleaning up containers...$(NC)"
	@$(COMPOSE) down
	@echo "$(GREEN)✓ Cleanup complete (volumes preserved)$(NC)"

clean-all: ## Remove containers AND volumes (DESTRUCTIVE!)
	@echo "$(RED)⚠ WARNING: This will delete all data!$(NC)"
	@read -p "Are you sure? Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || (echo "$(YELLOW)Cancelled$(NC)" && exit 1)
	@$(COMPOSE) down -v
	@echo "$(GREEN)✓ Complete cleanup done$(NC)"

prune: ## Clean up Docker system (images, cache)
	@echo "$(YELLOW)→ Pruning Docker system...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)✓ System pruned$(NC)"

validate: ## Run deployment validation
	@echo "$(BLUE)→ Running validation checks...$(NC)"
	@./scripts/validate-deployment.sh

##@ Development

shell: ## Open bash shell in Pentaho container
	@$(COMPOSE) exec pentaho-server bash

mssql-shell: ## Open SQL Server CLI
	@$(COMPOSE) exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$${MSSQL_SA_PASSWORD:-Password123!}" -C

status: ## Show container status
	@$(COMPOSE) ps

ps: ## List running containers (alias for status)
	@$(COMPOSE) ps

stats: ## Show resource usage stats
	@docker stats --no-stream pentaho-server pentaho-mssql 2>/dev/null || echo "$(YELLOW)Containers not running$(NC)"

##@ Information

urls: ## Display service URLs and credentials
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════$(NC)"
	@echo "$(GREEN)  Pentaho MSSQL Ubuntu - Service Access$(NC)"
	@echo "$(GREEN)═══════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(BLUE)Service URLs:$(NC)"
	@echo "  Pentaho Server: $(YELLOW)http://localhost:$${PENTAHO_HTTP_PORT:-8090}/pentaho$(NC)"
	@echo ""
	@echo "$(BLUE)Default Credentials:$(NC)"
	@echo "  Pentaho:    $(GREEN)admin$(NC) / $(GREEN)password$(NC)"
	@echo "  SQL Server: $(GREEN)sa$(NC) / $(GREEN)$${MSSQL_SA_PASSWORD:-Password123!}$(NC)"
	@echo ""
	@echo "$(GREEN)═══════════════════════════════════════════$(NC)"
	@echo ""

version: ## Show Pentaho and SQL Server versions
	@echo "$(BLUE)Pentaho Version:$(NC) $${PENTAHO_VERSION:-11.0.0.0-237}"
	@echo -n "$(BLUE)SQL Server Version:$(NC) "
	@$(COMPOSE) exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$${MSSQL_SA_PASSWORD:-Password123!}" -Q "SELECT @@VERSION" -C 2>/dev/null | head -5 | tail -1 || echo "$(YELLOW)SQL Server not running$(NC)"

help: ## Display this help message
	@echo ""
	@echo "$(BLUE)╔════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║  Pentaho MSSQL Ubuntu - Makefile Helper                   ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Usage:$(NC)"
	@echo "  make $(GREEN)<target>$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-18s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make deploy              # Full automated deployment"
	@echo "  make up                  # Start all services"
	@echo "  make logs-follow         # Follow logs in real-time"
	@echo "  make backup              # Create database backup"
	@echo "  make shell               # Open Pentaho shell"
	@echo "  make urls                # Show service URLs"
	@echo ""
