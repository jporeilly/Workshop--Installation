# Troubleshooting Guide

This guide provides solutions for common issues encountered with the Pentaho Server Docker deployment.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Container Startup Issues](#container-startup-issues)
- [Database Connection Problems](#database-connection-problems)
- [Permission Errors](#permission-errors)
- [Memory Issues](#memory-issues)
- [Network Problems](#network-problems)
- [Web Interface Issues](#web-interface-issues)
- [Log Analysis](#log-analysis)
- [Complete Reset Procedures](#complete-reset-procedures)

## Quick Diagnostics

Run these commands first to understand the current state:

```bash
# Check container status
docker compose ps

# Check container health
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"

# View recent logs
docker compose logs --tail=50

# Check resource usage
docker stats --no-stream

# Validate deployment
./scripts/validate-deployment.sh
```

## Container Startup Issues

### Container Won't Start

**Symptoms:**
- Container shows "Exited" status
- Container keeps restarting

**Diagnosis:**
```bash
# Check exit code
docker compose ps -a

# View logs for error messages
docker compose logs pentaho-server
```

**Common Causes and Solutions:**

#### 1. Pentaho ZIP File Missing

```
File pentaho-server-ee-11.0.0.0-237.zip Not Found
```

**Solution:**
```bash
# Verify file exists
ls -la docker/stagedArtifacts/

# Copy file if missing
cp /path/to/pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
```

#### 2. Entrypoint Permission Denied

```
exec: "/docker-entrypoint.sh": permission denied
```

**Solution:**
```bash
# Add execute permission
chmod +x docker/entrypoint/docker-entrypoint.sh

# Rebuild container
docker compose build --no-cache pentaho-server
```

#### 3. Port Already in Use

```
Error: bind: address already in use
```

**Solution:**
```bash
# Find process using port
sudo lsof -i :8090

# Kill process or change port in .env
PENTAHO_HTTP_PORT=8091
```

### MySQL Container Fails to Start

**Symptoms:**
- MySQL container unhealthy
- "InnoDB: Unable to lock" errors

**Solution:**
```bash
# Remove potentially corrupted volume
docker compose down
docker volume rm pentaho-server-mysql_pentaho_mysql_data

# Restart
docker compose up -d mysql
```

## Database Connection Problems

### Unable to Load MySQL Driver

```
Unable to load class: com.mysql.jdbc.Driver
```

**Cause:** MySQL JDBC driver not in classpath

**Solution:**
```bash
# Verify driver exists
ls -la softwareOverride/1_drivers/tomcat/lib/

# If missing, download driver
curl -L "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.3.0/mysql-connector-j-8.3.0.jar" \
  -o softwareOverride/1_drivers/tomcat/lib/mysql-connector-j-8.3.0.jar

# Rebuild container
docker compose build --no-cache pentaho-server
docker compose up -d pentaho-server
```

### MySQL Connection Refused

```
Communications link failure
java.net.ConnectException: Connection refused
```

**Diagnosis:**
```bash
# Check if MySQL is running
docker compose ps mysql

# Check MySQL logs
docker compose logs mysql

# Test MySQL connectivity
docker compose exec mysql mysqladmin ping -uroot -ppassword
```

**Solutions:**

1. **Wait for MySQL to initialize:**
   ```bash
   # Watch MySQL logs
   docker compose logs -f mysql
   # Wait for "ready for connections"
   ```

2. **Check MySQL health:**
   ```bash
   docker inspect pentaho-mysql --format='{{.State.Health.Status}}'
   ```

3. **Restart MySQL:**
   ```bash
   docker compose restart mysql
   ```

### Database Not Initialized

**Symptoms:**
- Database tables missing
- "Table doesn't exist" errors

**Diagnosis:**
```bash
# Check if databases exist
docker compose exec mysql mysql -uroot -ppassword -e "SHOW DATABASES;"
```

**Solution:**
```bash
# Recreate MySQL with fresh volumes
docker compose down
docker volume rm pentaho-server-mysql_pentaho_mysql_data
docker compose up -d mysql

# Wait for initialization
docker compose logs -f mysql
```

### HibernateUtil Errors

```
HIBUTIL.ERROR_0006 - Building SessionFactory failed
```

**Causes:**
- MySQL not ready
- Incorrect database credentials
- Missing database tables

**Solution:**
```bash
# Verify database users and permissions
docker compose exec mysql mysql -uroot -ppassword

# Check user exists
SELECT user, host FROM mysql.user;

# Verify database access
SHOW GRANTS FOR 'hibuser'@'%';
```

## Permission Errors

### Log File Permission Denied

```
java.io.FileNotFoundException: /opt/pentaho/.../logs/catalina.log (Permission denied)
```

**Cause:** Container runs as user `pentaho` (UID 5000) but logs directory has different ownership

**Solution:**
The logs volume is now commented out by default. Access logs via:
```bash
docker compose logs pentaho-server
```

If you need file-based logs:
```bash
# Create logs directory with correct permissions
mkdir -p logs
sudo chown 5000:5000 logs

# Uncomment logs volume in docker-compose.yml
# - ./logs:/opt/pentaho/pentaho-server/tomcat/logs
```

### kettle.properties Not Found

```
FileNotFoundException: /home/pentaho/.kettle/kettle.properties
```

**Solution:**
```bash
# Create kettle.properties
echo "# Kettle Properties" > config/.kettle/kettle.properties
```

### Solutions Directory Permission Issues

```
Error writing to pentaho-solutions
```

**Solution:**
```bash
# Fix permissions on named volume
docker compose exec pentaho-server chown -R pentaho:pentaho /opt/pentaho/pentaho-server/pentaho-solutions
```

## Memory Issues

### OutOfMemoryError

```
java.lang.OutOfMemoryError: Java heap space
```

**Diagnosis:**
```bash
# Check current memory usage
docker stats pentaho-server --no-stream

# Check container limits
docker inspect pentaho-server --format='{{.HostConfig.Memory}}'
```

**Solution:**
```bash
# Increase JVM memory in .env
PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=8192m

# Restart container
docker compose up -d pentaho-server
```

### Container Killed by OOM

```
Container killed due to OOM
```

**Solution:**
```bash
# Check host memory
free -h

# Reduce memory allocation or add swap
# Edit docker-compose.yml to add memory limits
deploy:
  resources:
    limits:
      memory: 6G
```

### Slow Garbage Collection

**Symptoms:**
- Application freezes periodically
- High GC pause times in logs

**Solution:**
Add GC tuning to `docker-compose.yml`:
```yaml
environment:
  - CATALINA_OPTS=-Xms4g -Xmx8g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+ParallelRefProcEnabled
```

## Network Problems

### Cannot Connect to Service by Hostname

```
Unknown host: repository
```

**Diagnosis:**
```bash
# Check network exists
docker network ls | grep pentaho

# Check containers are on same network
docker network inspect pentaho-server-mysql_pentaho-net
```

**Solution:**
```bash
# Recreate network
docker compose down
docker compose up -d
```

### Port Conflict with VPN

**Symptoms:**
- Services unreachable when VPN connected
- IP address conflicts

**Solution:**
The default subnet (172.28.0.0/16) is chosen to avoid common VPN ranges. If you still have conflicts:

```yaml
# Edit docker-compose.yml
networks:
  pentaho-net:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.200.0/24  # Choose non-conflicting subnet
```

### Firewall Blocking Ports

```bash
# Check UFW status
sudo ufw status

# Allow required ports
sudo ufw allow 8090/tcp
sudo ufw allow 8443/tcp
```

## Web Interface Issues

### 404 Not Found

```
HTTP Status 404 - /pentaho/
```

**Causes:**
1. Pentaho webapp not deployed
2. Server still starting
3. Configuration error

**Diagnosis:**
```bash
# Check if webapp exists
docker compose exec pentaho-server ls /opt/pentaho/pentaho-server/tomcat/webapps/

# Check Tomcat logs
docker compose logs pentaho-server | grep -i "deployed"
```

### Login Fails

```
Invalid username or password
```

**Default Credentials:**
- Username: `admin`
- Password: `password`

**If changed and forgotten:**
```bash
# Reset to memory-based authentication
# Copy fresh security config
docker compose exec pentaho-server cp /docker-entrypoint-init/3_security/pentaho-solutions/system/applicationContext-spring-security-memory.xml \
  /opt/pentaho/pentaho-server/pentaho-solutions/system/

# Restart
docker compose restart pentaho-server
```

### Slow Page Load

**Diagnosis:**
```bash
# Check response time
time curl -s -o /dev/null http://localhost:8090/pentaho/

# Check server resources
docker stats
```

**Solutions:**
1. Increase JVM memory
2. Check MySQL performance
3. Enable query caching
4. Reduce concurrent users

## Log Analysis

### Viewing Logs

```bash
# All services
docker compose logs

# Specific service with follow
docker compose logs -f pentaho-server

# Last N lines
docker compose logs --tail=100 pentaho-server

# Since timestamp
docker compose logs --since="2024-01-12T10:00:00" pentaho-server
```

### Log Locations in Container

```bash
docker compose exec pentaho-server bash

# Tomcat logs (if volume mounted)
ls /opt/pentaho/pentaho-server/tomcat/logs/

# Pentaho logs
ls /opt/pentaho/pentaho-server/logs/
```

### Searching Logs

```bash
# Find errors
docker compose logs pentaho-server 2>&1 | grep -i error

# Find specific exception
docker compose logs pentaho-server 2>&1 | grep -i "SQLException"

# Find startup completion
docker compose logs pentaho-server 2>&1 | grep "Server startup"
```

### Log Levels

To increase logging verbosity, modify log4j2 configuration in softwareOverride:
```xml
<Logger name="org.pentaho" level="DEBUG"/>
```

## Complete Reset Procedures

### Soft Reset (Keep Data)

```bash
# Stop and remove containers
docker compose down

# Rebuild images
docker compose build --no-cache

# Start fresh
docker compose up -d
```

### Hard Reset (Delete All Data)

**WARNING: This deletes all databases and uploaded content!**

```bash
# Stop and remove everything including volumes
docker compose down -v

# Remove any cached images
docker image prune -f

# Start fresh
docker compose up -d
```

### Reset Single Service

```bash
# Pentaho Server only
docker compose stop pentaho-server
docker compose rm -f pentaho-server
docker compose build --no-cache pentaho-server
docker compose up -d pentaho-server

# MySQL only (WARNING: deletes data)
docker compose stop mysql
docker compose rm -f mysql
docker volume rm pentaho-server-mysql_pentaho_mysql_data
docker compose up -d mysql
```

### Restore from Backup

```bash
# Stop services
docker compose down

# Remove current MySQL volume
docker volume rm pentaho-server-mysql_pentaho_mysql_data

# Start MySQL
docker compose up -d mysql

# Wait for MySQL to initialize
sleep 30

# Restore backup
./scripts/restore-mysql.sh backups/your-backup.sql.gz

# Start remaining services
docker compose up -d
```

## Getting Help

If you can't resolve an issue:

1. **Collect diagnostic information:**
   ```bash
   ./scripts/validate-deployment.sh > diagnostic.txt
   docker compose logs >> diagnostic.txt 2>&1
   docker compose ps -a >> diagnostic.txt
   ```

2. **Check documentation:**
   - [README.md](README.md) - Overview
   - [ARCHITECTURE.md](ARCHITECTURE.md) - System design
   - [CONFIGURATION.md](CONFIGURATION.md) - Configuration options

3. **Search for similar issues:**
   - Pentaho Community Forums
   - Docker Community
   - Stack Overflow

4. **Report issues:**
   Include diagnostic information, steps to reproduce, and expected vs actual behavior.

## Related Documentation

- [README.md](README.md) - Quick start guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [CONFIGURATION.md](CONFIGURATION.md) - Configuration reference
- [softwareOverride/README.md](softwareOverride/README.md) - Override system
