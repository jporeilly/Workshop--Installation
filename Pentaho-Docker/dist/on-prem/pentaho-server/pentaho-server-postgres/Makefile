# =============================================================================
# Pentaho Server 11 with PostgreSQL 15 - Makefile
# =============================================================================
# Usage: make [target]
# =============================================================================

COMPOSE_FILE = docker-compose-postgres.yaml
BACKUP_DIR = ./backups

.PHONY: help build up down start stop restart logs logs-pentaho logs-postgres status shell shell-postgres backup restore clean

# Default target
help:
	@echo "Pentaho Server 11 with PostgreSQL 15 - Available Commands"
	@echo "=========================================================="
	@echo ""
	@echo "  make build          - Build the Pentaho Server Docker image"
	@echo "  make up             - Start all services (detached)"
	@echo "  make down           - Stop and remove all services"
	@echo "  make start          - Start stopped services"
	@echo "  make stop           - Stop running services"
	@echo "  make restart        - Restart all services"
	@echo ""
	@echo "  make logs           - View logs from all services"
	@echo "  make logs-pentaho   - View Pentaho Server logs"
	@echo "  make logs-postgres  - View PostgreSQL logs"
	@echo ""
	@echo "  make status         - Show status of all services"
	@echo "  make shell          - Open shell in Pentaho container"
	@echo "  make shell-postgres - Open psql shell in PostgreSQL"
	@echo ""
	@echo "  make backup         - Backup PostgreSQL databases"
	@echo "  make restore        - Restore from latest backup"
	@echo "  make clean          - Remove all containers, volumes, and networks"
	@echo ""

# Build the Pentaho Server Docker image
build:
	@echo "Building Pentaho Server Docker image..."
	cd ../../../../assemblies/pentaho-server && docker build -t pentaho/pentaho-server:$${PENTAHO_VERSION:-11.0.0.0-237} .

# Start all services
up:
	@echo "Starting Pentaho Server and PostgreSQL..."
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo ""
	@echo "Services starting. Access Pentaho at: http://localhost:$${PORT:-8090}/pentaho"
	@echo "Default login: admin / password"

# Stop and remove all services
down:
	@echo "Stopping and removing services..."
	docker-compose -f $(COMPOSE_FILE) down

# Start stopped services
start:
	docker-compose -f $(COMPOSE_FILE) start

# Stop running services
stop:
	docker-compose -f $(COMPOSE_FILE) stop

# Restart all services
restart:
	@echo "Restarting services..."
	docker-compose -f $(COMPOSE_FILE) restart

# View logs from all services
logs:
	docker-compose -f $(COMPOSE_FILE) logs -f

# View Pentaho Server logs
logs-pentaho:
	docker-compose -f $(COMPOSE_FILE) logs -f pentaho-server

# View PostgreSQL logs
logs-postgres:
	docker-compose -f $(COMPOSE_FILE) logs -f repository

# Show status of all services
status:
	@echo "=== Container Status ==="
	docker-compose -f $(COMPOSE_FILE) ps
	@echo ""
	@echo "=== Health Status ==="
	@docker inspect --format='{{.Name}}: {{.State.Health.Status}}' pentaho-postgres 2>/dev/null || echo "PostgreSQL: not running"

# Open shell in Pentaho container
shell:
	docker exec -it pentaho-server /bin/bash

# Open psql shell in PostgreSQL
shell-postgres:
	docker exec -it pentaho-postgres psql -U postgres

# Backup PostgreSQL databases
backup:
	@mkdir -p $(BACKUP_DIR)
	@echo "Backing up PostgreSQL databases..."
	@BACKUP_FILE=$(BACKUP_DIR)/pentaho_backup_$$(date +%Y%m%d_%H%M%S).sql && \
	docker exec pentaho-postgres pg_dumpall -U postgres > $$BACKUP_FILE && \
	echo "Backup created: $$BACKUP_FILE"

# Restore from latest backup
restore:
	@LATEST=$$(ls -t $(BACKUP_DIR)/*.sql 2>/dev/null | head -1) && \
	if [ -z "$$LATEST" ]; then \
		echo "No backup files found in $(BACKUP_DIR)"; \
		exit 1; \
	fi && \
	echo "Restoring from: $$LATEST" && \
	docker exec -i pentaho-postgres psql -U postgres < $$LATEST && \
	echo "Restore completed"

# Remove all containers, volumes, and networks (CAUTION: destroys data)
clean:
	@echo "WARNING: This will remove all containers, volumes, and data!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	docker-compose -f $(COMPOSE_FILE) down -v --remove-orphans
	@echo "Cleanup completed"
