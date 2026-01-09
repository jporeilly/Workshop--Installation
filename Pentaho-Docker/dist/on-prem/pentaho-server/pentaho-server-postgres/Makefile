# =============================================================================
# Pentaho Server 11 with PostgreSQL 15 - Makefile
# =============================================================================
# Usage: make [target]
# =============================================================================

COMPOSE_FILE = docker-compose-postgres.yaml
COMPOSE_CMD = docker compose
BACKUP_DIR = ./backups

.PHONY: help build up down start stop restart logs logs-pentaho logs-postgres status shell shell-postgres backup restore clean

help:
	@echo "Pentaho Server 11 with PostgreSQL 15 - Available Commands"
	@echo "=========================================================="
	@echo ""
	@echo "  make build          - Build the Pentaho Server Docker image"
	@echo "  make up             - Start all services (detached)"
	@echo "  make down           - Stop and remove all services"
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
	@echo "  make clean          - Remove all containers, volumes, and networks"
	@echo ""

build:
	@echo "Building Pentaho Server Docker image..."
	cd ../../../../assemblies/pentaho-server && docker build -t pentaho/pentaho-server:$${PENTAHO_VERSION:-11.0.0.0-237} .

up:
	@echo "Starting Pentaho Server and PostgreSQL..."
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) up -d
	@echo ""
	@echo "Services starting. Access Pentaho at: http://localhost:$${PORT:-8090}/pentaho"
	@echo "Default login: admin / password"

down:
	@echo "Stopping and removing services..."
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) down

start:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) start

stop:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) stop

restart:
	@echo "Restarting services..."
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) restart

logs:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs -f

logs-pentaho:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs -f pentaho-server

logs-postgres:
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) logs -f repository

status:
	@echo "=== Container Status ==="
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) ps
	@echo ""
	@echo "=== Health Status ==="
	@docker inspect --format='{{.Name}}: {{.State.Health.Status}}' pentaho-postgres 2>/dev/null || echo "PostgreSQL: not running"

shell:
	docker exec -it pentaho-server /bin/bash

shell-postgres:
	docker exec -it pentaho-postgres psql -U postgres

backup:
	@mkdir -p $(BACKUP_DIR)
	@echo "Backing up PostgreSQL databases..."
	@BACKUP_FILE=$(BACKUP_DIR)/pentaho_backup_$$(date +%Y%m%d_%H%M%S).sql && \
	docker exec pentaho-postgres pg_dumpall -U postgres > $$BACKUP_FILE && \
	echo "Backup created: $$BACKUP_FILE"

clean:
	@echo "WARNING: This will remove all containers, volumes, and data!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	$(COMPOSE_CMD) -f $(COMPOSE_FILE) down -v --remove-orphans
	@echo "Cleanup completed"
