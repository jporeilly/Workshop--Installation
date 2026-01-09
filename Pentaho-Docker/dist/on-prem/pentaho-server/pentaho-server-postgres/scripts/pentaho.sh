#!/bin/bash
# =============================================================================
# Pentaho Server 11 with PostgreSQL 15 - Bash Helper Script
# =============================================================================
# Usage: ./scripts/pentaho.sh [command]
# =============================================================================

set -e

COMPOSE_FILE="docker-compose-postgres.yaml"
BACKUP_DIR="./backups"

show_help() {
    echo "Pentaho Server 11 with PostgreSQL 15 - Available Commands"
    echo "=========================================================="
    echo ""
    echo "  ./scripts/pentaho.sh build          - Build the Pentaho Server Docker image"
    echo "  ./scripts/pentaho.sh up             - Start all services (detached)"
    echo "  ./scripts/pentaho.sh down           - Stop and remove all services"
    echo "  ./scripts/pentaho.sh start          - Start stopped services"
    echo "  ./scripts/pentaho.sh stop           - Stop running services"
    echo "  ./scripts/pentaho.sh restart        - Restart all services"
    echo ""
    echo "  ./scripts/pentaho.sh logs           - View logs from all services"
    echo "  ./scripts/pentaho.sh logs-pentaho   - View Pentaho Server logs"
    echo "  ./scripts/pentaho.sh logs-postgres  - View PostgreSQL logs"
    echo ""
    echo "  ./scripts/pentaho.sh status         - Show status of all services"
    echo "  ./scripts/pentaho.sh shell          - Open shell in Pentaho container"
    echo "  ./scripts/pentaho.sh shell-postgres - Open psql shell in PostgreSQL"
    echo ""
    echo "  ./scripts/pentaho.sh backup         - Backup PostgreSQL databases"
    echo "  ./scripts/pentaho.sh restore        - Restore from latest backup"
    echo "  ./scripts/pentaho.sh clean          - Remove all containers, volumes, and networks"
    echo ""
}

do_build() {
    echo "Building Pentaho Server Docker image..."
    cd "$(dirname "$0")/../../../../assemblies/pentaho-server"
    VERSION="${PENTAHO_VERSION:-11.0.0.0-237}"
    docker build -t "pentaho/pentaho-server:$VERSION" .
    cd - > /dev/null
}

do_up() {
    echo "Starting Pentaho Server and PostgreSQL..."
    docker-compose -f "$COMPOSE_FILE" up -d
    echo ""
    echo "Services starting. Access Pentaho at: http://localhost:${PORT:-8090}/pentaho"
    echo "Default login: admin / password"
}

do_down() {
    echo "Stopping and removing services..."
    docker-compose -f "$COMPOSE_FILE" down
}

do_start() {
    docker-compose -f "$COMPOSE_FILE" start
}

do_stop() {
    docker-compose -f "$COMPOSE_FILE" stop
}

do_restart() {
    echo "Restarting services..."
    docker-compose -f "$COMPOSE_FILE" restart
}

do_logs() {
    docker-compose -f "$COMPOSE_FILE" logs -f
}

do_logs_pentaho() {
    docker-compose -f "$COMPOSE_FILE" logs -f pentaho-server
}

do_logs_postgres() {
    docker-compose -f "$COMPOSE_FILE" logs -f repository
}

do_status() {
    echo "=== Container Status ==="
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""
    echo "=== Health Status ==="
    docker inspect --format='{{.Name}}: {{.State.Health.Status}}' pentaho-postgres 2>/dev/null || echo "PostgreSQL: not running"
}

do_shell() {
    docker exec -it pentaho-server /bin/bash
}

do_shell_postgres() {
    docker exec -it pentaho-postgres psql -U postgres
}

do_backup() {
    mkdir -p "$BACKUP_DIR"
    echo "Backing up PostgreSQL databases..."
    BACKUP_FILE="$BACKUP_DIR/pentaho_backup_$(date +%Y%m%d_%H%M%S).sql"
    docker exec pentaho-postgres pg_dumpall -U postgres > "$BACKUP_FILE"
    echo "Backup created: $BACKUP_FILE"
}

do_restore() {
    LATEST=$(ls -t "$BACKUP_DIR"/*.sql 2>/dev/null | head -1)
    if [ -z "$LATEST" ]; then
        echo "No backup files found in $BACKUP_DIR"
        exit 1
    fi
    echo "Restoring from: $LATEST"
    docker exec -i pentaho-postgres psql -U postgres < "$LATEST"
    echo "Restore completed"
}

do_clean() {
    echo "WARNING: This will remove all containers, volumes, and data!"
    read -p "Are you sure? [y/N] " confirm
    if [ "$confirm" != "y" ]; then
        echo "Cancelled"
        exit 0
    fi
    docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
    echo "Cleanup completed"
}

# Main
case "${1:-help}" in
    help)           show_help ;;
    build)          do_build ;;
    up)             do_up ;;
    down)           do_down ;;
    start)          do_start ;;
    stop)           do_stop ;;
    restart)        do_restart ;;
    logs)           do_logs ;;
    logs-pentaho)   do_logs_pentaho ;;
    logs-postgres)  do_logs_postgres ;;
    status)         do_status ;;
    shell)          do_shell ;;
    shell-postgres) do_shell_postgres ;;
    backup)         do_backup ;;
    restore)        do_restore ;;
    clean)          do_clean ;;
    *)              show_help ;;
esac
