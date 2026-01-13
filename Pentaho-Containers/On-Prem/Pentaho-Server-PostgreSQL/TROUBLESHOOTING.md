# Troubleshooting Guide

## Quick Diagnostics

```bash
# Check all services
./scripts/validate-deployment.sh

# View service status
docker compose ps

# View logs
docker compose logs -f

# Check resource usage
docker stats
```

## Common Issues

### PostgreSQL Won't Start

**Symptoms:** PostgreSQL container fails to start or keeps restarting

**Check logs:**
```bash
docker compose logs postgres
```

**Common causes:**

1. **Port already in use**
   ```bash
   # Check if port 5432 is used
   ss -tuln | grep 5432

   # Change port in .env
   POSTGRES_PORT=5433
   ```

2. **Permission issues on volumes**
   ```bash
   # Reset PostgreSQL data
   docker compose down -v
   docker compose up -d postgres
   ```

3. **Disk space**
   ```bash
   df -h
   ```

### Pentaho Server Won't Start

**Symptoms:** Pentaho container exits or gets stuck during startup

**Check logs:**
```bash
docker compose logs pentaho-server
```

**Common causes:**

1. **PostgreSQL not ready**
   ```bash
   # Verify PostgreSQL is healthy
   docker compose ps postgres
   docker exec pentaho-postgres pg_isready -U postgres
   ```

2. **Insufficient memory**
   ```bash
   # Check available memory
   free -h

   # Reduce JVM heap in .env
   PENTAHO_MAX_MEMORY=2048m
   ```

3. **Configuration errors**
   ```bash
   # Check context.xml syntax
   docker compose logs pentaho-server | grep -i error
   ```

4. **Missing Pentaho package**
   ```bash
   ls -la docker/stagedArtifacts/*.zip
   ```

### Database Connection Errors

**Symptoms:** "Connection refused" or timeout errors

**Verify connectivity:**
```bash
# Test PostgreSQL connection
docker exec pentaho-postgres psql -U postgres -c "SELECT 1"

# Check databases exist
docker exec pentaho-postgres psql -U postgres -c "\l"
```

**Check JDBC configuration:**
```bash
# Verify context.xml has correct host
grep -i "repository" softwareOverride/2_repository/tomcat/webapps/pentaho/META-INF/context.xml
```

### Login Page Not Loading

**Symptoms:** Cannot access http://localhost:8090/pentaho

**Check Pentaho health:**
```bash
# Is container running?
docker compose ps pentaho-server

# Can you reach the port?
curl -v http://localhost:8090/pentaho/Login

# Check logs for startup completion
docker compose logs pentaho-server | grep "Server startup"
```

**Firewall issues:**
```bash
# Check if port is open
sudo ufw status
```

### Quartz Scheduler Errors

**Symptoms:** Scheduled jobs not running, errors in logs

**Check Quartz tables:**
```bash
docker exec pentaho-postgres psql -U pentaho_user -d quartz -c "\dt"
```

**Verify quartz.properties:**
```bash
cat softwareOverride/2_repository/pentaho-solutions/system/scheduler-plugin/quartz/quartz.properties | grep -i delegate
# Should show: PostgreSQLDelegate
```

### Jackrabbit Repository Errors

**Symptoms:** Content not saving, JCR errors

**Check Jackrabbit database:**
```bash
docker exec pentaho-postgres psql -U jcr_user -d jackrabbit -c "\dt"
```

**Reset repository (DESTRUCTIVE):**
```bash
# Stop Pentaho
docker compose stop pentaho-server

# Clear Jackrabbit tables
docker exec pentaho-postgres psql -U postgres -d jackrabbit -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# Restart
docker compose start pentaho-server
```

### Performance Issues

**Symptoms:** Slow response, high resource usage

**Check resources:**
```bash
docker stats --no-stream
```

**Increase JVM memory:**
```bash
# Edit .env
PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=8192m

# Restart
docker compose restart pentaho-server
```

**Check PostgreSQL performance:**
```bash
docker exec pentaho-postgres psql -U postgres -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
```

## Log Locations

| Service | Location |
|---------|----------|
| PostgreSQL | `docker compose logs postgres` |
| Pentaho | `docker compose logs pentaho-server` |
| Tomcat | Container: `/opt/pentaho/pentaho-server/tomcat/logs/` |

## Reset Procedures

### Soft Reset (Keep Data)

```bash
docker compose restart
```

### Hard Reset (Lose Configuration)

```bash
docker compose down
docker compose up -d
```

### Complete Reset (Lose Everything)

```bash
# WARNING: Deletes all data!
docker compose down -v
docker compose up -d
```

## Getting Help

1. Check logs: `docker compose logs -f`
2. Run validation: `./scripts/validate-deployment.sh`
3. Review configuration: Compare with working MySQL version
4. Check Pentaho documentation: https://help.hitachivantara.com/

## Debug Mode

Enable verbose logging:

```bash
# Edit softwareOverride/4_others/tomcat/bin/startup.sh
# Add: -Dlog4j.debug=true

docker compose restart pentaho-server
```
