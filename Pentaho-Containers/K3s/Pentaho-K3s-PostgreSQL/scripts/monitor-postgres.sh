#!/bin/bash
# =============================================================================
# PostgreSQL Monitoring Script
# =============================================================================
# Monitor PostgreSQL database health and performance metrics
#
# Displays:
#   - Database sizes
#   - Active connections
#   - Table sizes
#   - Quartz scheduler lock status
#   - Query performance statistics
#   - Cache hit ratios
#
# Usage: ./scripts/monitor-postgres.sh
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
echo -e "  PostgreSQL Monitoring - Pentaho"
echo -e "==============================================${NC}\n"

# Check if PostgreSQL pod exists
POSTGRES_POD=$(kubectl get pods -n $NAMESPACE -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POSTGRES_POD" ]; then
    echo -e "${RED}PostgreSQL pod not found${NC}"
    exit 1
fi

# Database Sizes
echo -e "${YELLOW}=== Database Sizes ===${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -c "
SELECT
    datname as database,
    pg_size_pretty(pg_database_size(datname)) as size,
    pg_database_size(datname) as size_bytes
FROM pg_database
WHERE datname IN ('jackrabbit', 'quartz', 'hibernate', 'postgres')
ORDER BY pg_database_size(datname) DESC;
" 2>/dev/null
echo ""

# Active Connections
echo -e "${YELLOW}=== Active Connections ===${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -c "
SELECT
    datname as database,
    count(*) as connections,
    max(state) as max_state
FROM pg_stat_activity
WHERE datname IS NOT NULL
GROUP BY datname
ORDER BY connections DESC;
" 2>/dev/null
echo ""

# Connection Details
echo -e "${YELLOW}=== Connection Details ===${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -c "
SELECT
    usename as user,
    application_name,
    client_addr,
    state,
    count(*) as count
FROM pg_stat_activity
WHERE datname IN ('jackrabbit', 'quartz', 'hibernate')
GROUP BY usename, application_name, client_addr, state
ORDER BY count DESC;
" 2>/dev/null
echo ""

# Quartz Scheduler Status
echo -e "${YELLOW}=== Quartz Scheduler Locks ===${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U pentaho_user -d quartz -c "
SELECT
    sched_name,
    lock_name
FROM qrtz6_locks
ORDER BY lock_name;
" 2>/dev/null || echo -e "${RED}Unable to query Quartz locks${NC}"
echo ""

# Quartz Job Count
echo -e "${YELLOW}=== Quartz Jobs ===${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U pentaho_user -d quartz -c "
SELECT
    'Total Jobs' as metric,
    count(*) as count
FROM qrtz6_job_details
UNION ALL
SELECT
    'Total Triggers' as metric,
    count(*) as count
FROM qrtz6_triggers
UNION ALL
SELECT
    'Fired Triggers' as metric,
    count(*) as count
FROM qrtz6_fired_triggers;
" 2>/dev/null || echo -e "${YELLOW}No Quartz jobs yet${NC}"
echo ""

# Table Sizes (Top 10)
echo -e "${YELLOW}=== Largest Tables (Top 10) ===${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -d quartz -c "
SELECT
    schemaname || '.' || tablename as table_name,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as data_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) -
                   pg_relation_size(schemaname||'.'||tablename)) as index_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
" 2>/dev/null
echo ""

# Cache Hit Ratio
echo -e "${YELLOW}=== Cache Hit Ratio ===${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -c "
SELECT
    'Cache Hit Ratio' as metric,
    round(100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 2) || '%' as value
FROM pg_stat_database
WHERE datname IN ('jackrabbit', 'quartz', 'hibernate');
" 2>/dev/null
echo ""

# Database Statistics
echo -e "${YELLOW}=== Database Statistics ===${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -c "
SELECT
    datname as database,
    numbackends as connections,
    xact_commit as commits,
    xact_rollback as rollbacks,
    blks_read as disk_reads,
    blks_hit as cache_hits,
    tup_returned as rows_returned,
    tup_fetched as rows_fetched,
    tup_inserted as rows_inserted,
    tup_updated as rows_updated,
    tup_deleted as rows_deleted
FROM pg_stat_database
WHERE datname IN ('jackrabbit', 'quartz', 'hibernate')
ORDER BY datname;
" 2>/dev/null
echo ""

# Long Running Queries
echo -e "${YELLOW}=== Long Running Queries (> 1 second) ===${NC}"
LONG_QUERIES=$(kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -c "
SELECT
    pid,
    usename,
    datname,
    now() - query_start as duration,
    state,
    left(query, 60) as query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '1 second'
  AND query NOT LIKE '%pg_stat_activity%'
ORDER BY duration DESC;
" 2>/dev/null)

if echo "$LONG_QUERIES" | grep -q "row"; then
    echo "$LONG_QUERIES"
else
    echo -e "${GREEN}No long-running queries${NC}"
fi
echo ""

# Replication Status (if configured)
echo -e "${YELLOW}=== Replication Status ===${NC}"
REPLICATION=$(kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -c "
SELECT
    client_addr,
    state,
    sync_state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) as send_lag,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) as replay_lag
FROM pg_stat_replication;
" 2>/dev/null)

if echo "$REPLICATION" | grep -q "row"; then
    echo "$REPLICATION"
else
    echo -e "${YELLOW}No replication configured (single-node)${NC}"
fi
echo ""

# PostgreSQL Version and Uptime
echo -e "${YELLOW}=== PostgreSQL Information ===${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -c "
SELECT
    'Version' as info,
    version() as value
UNION ALL
SELECT
    'Uptime' as info,
    now() - pg_postmaster_start_time() as value;
" 2>/dev/null
echo ""

# Storage and Backup Info
echo -e "${YELLOW}=== Storage Information ===${NC}"
echo -e "${BLUE}PostgreSQL Data Directory:${NC}"
kubectl exec -n $NAMESPACE $POSTGRES_POD -- df -h /var/lib/postgresql/data 2>/dev/null
echo ""

# Health Summary
echo -e "${BLUE}=============================================="
echo -e "  Health Summary"
echo -e "==============================================${NC}"

# Check for issues
ISSUES=0

# Check connection count
CONN_COUNT=$(kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity WHERE datname IN ('jackrabbit', 'quartz', 'hibernate');" 2>/dev/null | tr -d ' ')
if [ "$CONN_COUNT" -gt 50 ]; then
    echo -e "${RED}⚠ High connection count: $CONN_COUNT (max recommended: 50)${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ Connection count: $CONN_COUNT${NC}"
fi

# Check cache hit ratio
CACHE_RATIO=$(kubectl exec -n $NAMESPACE $POSTGRES_POD -- psql -U postgres -t -c "
SELECT round(100.0 * sum(blks_hit) / nullif(sum(blks_hit) + sum(blks_read), 0), 0)
FROM pg_stat_database
WHERE datname IN ('jackrabbit', 'quartz', 'hibernate');
" 2>/dev/null | tr -d ' ')

if [ ! -z "$CACHE_RATIO" ] && [ "$CACHE_RATIO" -lt 90 ]; then
    echo -e "${YELLOW}⚠ Cache hit ratio: ${CACHE_RATIO}% (recommended: >95%)${NC}"
    echo -e "  Consider increasing shared_buffers in PostgreSQL config"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✓ Cache hit ratio: ${CACHE_RATIO}%${NC}"
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "\n${GREEN}✓ All health checks passed${NC}"
else
    echo -e "\n${YELLOW}⚠ $ISSUES issue(s) detected${NC}"
fi

echo ""
echo -e "${BLUE}=============================================="
echo -e "  End of PostgreSQL Report"
echo -e "==============================================${NC}\n"

# Quick commands
echo -e "Quick commands:"
echo -e "  ${BLUE}make db-shell${NC}                  # Connect to PostgreSQL"
echo -e "  ${BLUE}make backup${NC}                    # Backup databases"
echo -e "  ${BLUE}kubectl logs -n pentaho -l app=postgres${NC}  # View PostgreSQL logs"
echo ""
