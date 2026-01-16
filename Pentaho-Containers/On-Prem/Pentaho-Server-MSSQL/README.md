# Pentaho Server 11 Docker Deployment (SQL Server)

Complete, standalone Docker Compose deployment for Pentaho Server 11.0.0.0-237 with Microsoft SQL Server repository on Ubuntu 24.04.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Deployment](#manual-deployment)
- [Configuration](#configuration)
- [Software Override System](#software-override-system)
- [Architecture](#architecture)
- [Database Management](#database-management)
- [Troubleshooting](#troubleshooting)
- [Production Hardening](#production-hardening)
- [Backup and Recovery](#backup-and-recovery)
- [Project Structure](#project-structure)
- [Recent Changes](#recent-changes)

## Overview

This project provides a production-ready Docker Compose deployment for:

- **Pentaho Server 11.0.0.0-237** (Enterprise Edition)
- **Microsoft SQL Server 2022** (Developer Edition) with Pentaho repository databases

### Key Features

- Completely self-contained and portable
- Automated database initialization via mssql-init container
- Health checks and proper startup ordering
- Persistent data volumes
- Easy backup and restore
- Production-ready configuration templates
- Support for multiple SQL Server editions (Developer, Express, Standard, Enterprise)
- **HashiCorp Vault** for secrets management
- **Resource limits** (CPU/memory) for stability
- **Log rotation** to prevent disk exhaustion

## Prerequisites

### System Requirements

- **OS**: Ubuntu 24.04 LTS (also compatible with Ubuntu 22.04, 20.04)
- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB recommended (SQL Server requires 2GB minimum)
- **Disk**: 20GB+ available space
- **Ports**: 8090 (HTTP), 8443 (HTTPS), 1433 (SQL Server), 8200 (Vault)

### Software Requirements

1. **Docker Engine** 20.10+
   ```bash
   # Install Docker on Ubuntu
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   # Log out and back in for group changes to take effect
   ```

2. **Docker Compose** 2.0+
   ```bash
   # Verify installation
   docker compose version
   ```

3. **Pentaho Package**
   - Obtain `pentaho-server-ee-11.0.0.0-237.zip` from Hitachi Vantara
   - Place in `docker/stagedArtifacts/` directory

4. **MSSQL JDBC Driver**
   - Download Microsoft JDBC Driver for SQL Server from [Microsoft](https://learn.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server)
   - Extract and place `mssql-jdbc-12.8.1.jre11.jar` (or latest version) in `softwareOverride/1_drivers/tomcat/lib/`

## Quick Start

### 1. Prepare Pentaho Package

```bash
# Place your Pentaho package in the staged artifacts directory
cp /path/to/pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
```

### 2. Download MSSQL JDBC Driver

```bash
# Download Microsoft JDBC Driver from Maven Central
cd softwareOverride/1_drivers/tomcat/lib/
wget https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar
cd ../../../..
```

### 3. Configure Environment (Optional)

```bash
# Create .env file from template
cp .env.template .env

# Edit .env to customize settings (optional)
nano .env
```

### 4. Deploy

```bash
# Run automated deployment script
chmod +x deploy.sh
./deploy.sh
```

The script will:
- Validate prerequisites
- Build the Pentaho Server image
- Start SQL Server and initialize databases via mssql-init container
- Start Pentaho Server
- Display access URLs

### 5. Access Services

Once deployment completes:

- **Pentaho Server**: http://localhost:8090/pentaho
  - Username: `admin`
  - Password: `password`

## Manual Deployment

If you prefer manual control:

### 1. Create Environment File

```bash
cp .env.template .env
```

### 2. Build Pentaho Server Image

```bash
docker compose build --no-cache pentaho-server
```

### 3. Start Services

```bash
# Start SQL Server first
docker compose up -d mssql

# Wait for SQL Server to be ready (check logs)
docker compose logs -f mssql

# Run database initialization
docker compose up mssql-init

# Wait for initialization to complete
docker compose logs -f mssql-init

# Start Pentaho Server
docker compose up -d pentaho-server
```

### 4. Monitor Startup

```bash
# Watch Pentaho Server logs
docker compose logs -f pentaho-server

# Wait for "Server startup in [X] milliseconds"
```

### 5. Validate Deployment

```bash
./scripts/validate-deployment.sh
```

## Configuration

### Environment Variables

Edit `.env` file to customize:

```bash
# Pentaho Version
PENTAHO_VERSION=11.0.0.0-237

# SQL Server Configuration
MSSQL_SA_PASSWORD=YourStr0ng!Passw0rd    # Must meet SQL Server complexity requirements
MSSQL_PORT=1433
MSSQL_EDITION=Developer                  # Developer, Express, Standard, or Enterprise

# Pentaho Server Ports
PENTAHO_HTTP_PORT=8090
PENTAHO_HTTPS_PORT=8443

# JVM Memory Settings
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m                 # Adjust based on available RAM

# License (optional for EE features)
LICENSE_URL=http://your-server/pentaho-ee-license.lic
```

### SQL Server Password Requirements

SQL Server requires strong passwords with the following complexity requirements:

- At least 8 characters long
- Contains characters from three of the following four categories:
  - Uppercase letters (A-Z)
  - Lowercase letters (a-z)
  - Numbers (0-9)
  - Non-alphanumeric characters (!@#$%^&*()_+-=[]{}|;:,.<>?)

### SQL Server Editions

The deployment supports different SQL Server editions via the `MSSQL_EDITION` environment variable:

- **Developer**: Full-featured edition for development/testing (NOT licensed for production)
- **Express**: Free edition with limitations (10GB database size, limited resources)
- **Standard**: Production edition with moderate features (requires license)
- **Enterprise**: Full-featured production edition (requires license)

For production deployments, ensure you have appropriate SQL Server licensing.

### SQL Server Configuration

Customize SQL Server settings by creating `mssql-config/mssql.conf`:

```ini
[memory]
memorylimitmb = 4096

[sqlagent]
enabled = true

[network]
tcpport = 1433
```

### Pentaho Configuration Overrides

Files in `softwareOverride/` are automatically applied during container startup. See the [Software Override System](#software-override-system) section for detailed documentation.

## Software Override System

The `softwareOverride/` directory provides a powerful mechanism to customize Pentaho Server without modifying the core installation. Files are copied into the Pentaho installation during container startup, processed in alphabetical order by directory name.

### Directory Structure

```
softwareOverride/
├── 1_drivers/           # JDBC drivers and data connectors
│   ├── tomcat/lib/
│   │   └── mssql-jdbc-12.8.1.jre11.jar   # SQL Server JDBC driver
│   └── pentaho-solutions/drivers/         # Big data drivers (.kar files)
├── 2_repository/        # Database repository configuration
│   ├── pentaho-solutions/system/
│   │   ├── hibernate/hibernate-settings.xml
│   │   ├── jackrabbit/repository.xml
│   │   └── scheduler-plugin/quartz/quartz.properties
│   └── tomcat/webapps/pentaho/META-INF/context.xml
├── 3_security/          # Authentication and authorization
│   └── pentaho-solutions/system/
│       ├── applicationContext-spring-security-hibernate.properties
│       └── applicationContext-spring-security-memory.xml
├── 4_others/            # Tomcat, defaults, and miscellaneous
│   ├── pentaho-solutions/system/
│   │   ├── defaultUser.spring.properties
│   │   ├── pentaho.xml
│   │   └── security.properties
│   └── tomcat/
│       ├── bin/startup.sh
│       └── webapps/pentaho/WEB-INF/web.xml
└── 99_exchange/         # User data exchange (not auto-processed)
```

### Processing Order

Directories are processed alphabetically during container startup by the entrypoint script (`docker/entrypoint/docker-entrypoint.sh`):

1. **1_drivers** - First: Ensures JDBC drivers are available before database connections
2. **2_repository** - Second: Database and persistence configuration
3. **3_security** - Third: Authentication mechanisms
4. **4_others** - Fourth: Application-level settings

### MSSQL JDBC Driver

The Microsoft JDBC Driver for SQL Server is required at:
```
softwareOverride/1_drivers/tomcat/lib/mssql-jdbc-12.8.1.jre11.jar
```

This driver is required for Pentaho to connect to the SQL Server repository. Version 12.4.2 is compatible with SQL Server 2022.

**To download the driver:**
1. Visit [Microsoft JDBC Driver Download](https://learn.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server)
2. Download the latest version (12.4.2 or newer)
3. Extract the archive and locate `mssql-jdbc-12.8.1.jre11.jar`
4. Place in `softwareOverride/1_drivers/tomcat/lib/`
5. Rebuild the container: `docker compose build --no-cache pentaho-server`

**Important connection string parameters:**

All JDBC connection strings must include:
- `encrypt=false;trustServerCertificate=true` - Required for connections without SSL certificates
- Example: `jdbc:sqlserver://repository:1433;databaseName=jackrabbit;encrypt=false;trustServerCertificate=true`

### Adding Custom Configurations

1. Create matching directory structure under `softwareOverride/`
2. Place files with paths matching the Pentaho installation structure
3. Rebuild container: `docker compose build pentaho-server`
4. Restart: `docker compose up -d pentaho-server`

**Example - Adding a PostgreSQL JDBC driver:**
```bash
mkdir -p softwareOverride/1_drivers/tomcat/lib/
cp postgresql-42.7.1.jar softwareOverride/1_drivers/tomcat/lib/
docker compose build --no-cache pentaho-server
docker compose up -d pentaho-server
```

### Skipping Directories

Create a `.ignore` file in any directory to skip processing during startup.

## Architecture

### Services

```
┌─────────────────────────────────────────┐
│  vault:8200                             │
│  - HashiCorp Vault 1.15                 │
│  - Secrets Management                   │
│  - AppRole Authentication               │
└─────────────┬───────────────────────────┘
              │ Secrets API
              ▼
┌─────────────────────────────────────────┐
│  pentaho-server:8090                    │
│  - Pentaho Server 11.0.0.0-237          │
│  - Tomcat 9                             │
│  - OpenJDK 21                           │
│  - Resource Limits: 6GB RAM, 4 CPUs     │
└─────────────┬───────────────────────────┘
              │ JDBC Connection (port 1433)
              │ encrypt=false;trustServerCertificate=true
              ▼
┌─────────────────────────────────────────┐
│  mssql:1433 (hostname: repository)      │
│  - SQL Server 2022 (Developer Edition)  │
│  - Resource Limits: 4GB RAM, 2 CPUs     │
│  - 5 Pentaho Databases:                 │
│    • jackrabbit (JCR)                   │
│    • quartz (Scheduler)                 │
│    • hibernate (Repository)             │
│    • pentaho_dilogs (Logging)           │
│    • pentaho_operations_mart (Mart)     │
└───────────▲─────────────────────────────┘
            │ Initialization
┌───────────┴─────────────────────────────┐
│  mssql-init (one-time)                  │
│  - Creates databases and schemas        │
│  - Runs SQL initialization scripts      │
│  - Executes once then exits             │
└─────────────────────────────────────────┘
```

### Database Initialization

The `mssql-init` container runs initialization scripts from `db_init_mssql/` directory:

1. Waits for SQL Server to be ready
2. Creates Pentaho databases
3. Creates schemas and tables
4. Sets up users and permissions
5. Exits upon completion

### Data Persistence

Named Docker volumes ensure data persists across container restarts:

- `vault_data` - Vault data and unseal keys
- `pentaho_mssql_data` - SQL Server databases
- `pentaho_solutions` - Pentaho solutions repository
- `pentaho_data` - Pentaho data files

### Networking

Bridge network `pentaho-net` (172.28.0.0/16) provides:

- Service discovery (containers can reach each other by hostname)
- Network isolation from host
- Custom subnet to avoid VPN conflicts

## Vault and Secrets Management

### Overview

This deployment uses HashiCorp Vault for secure secrets management. Database credentials are stored in Vault rather than in plain text environment variables or configuration files.

### Clean Deployment Flow

On a **clean deployment** (first run), the following sequence ensures all components can communicate:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  1. docker compose up -d                                                 │
│                    ↓                                                     │
│  2. SQL Server starts → runs db_init_mssql/*.sql scripts                │
│     → Creates logins with default password "password"                   │
│                    ↓                                                     │
│  3. Vault container starts → vault-init.sh runs                         │
│     → Stores SAME default passwords in Vault (not random ones!)         │
│     → This ensures Pentaho can connect immediately                      │
│                    ↓                                                     │
│  4. Pentaho container starts → extra-entrypoint.sh runs                 │
│     → Fetches credentials from Vault                                    │
│     → Injects into context.xml                                          │
│                    ↓                                                     │
│  5. Pentaho connects to SQL Server successfully ✓                       │
│                    ↓                                                     │
│  6. AFTER VERIFICATION: Run ./scripts/rotate-secrets.sh                 │
│     → Generates secure random passwords                                 │
│     → Updates SQL Server logins (ALTER LOGIN)                           │
│     → Updates Vault secrets                                             │
│     → Restarts Pentaho to pick up new credentials                       │
└─────────────────────────────────────────────────────────────────────────┘
```

**Important**: Default passwords are **intentionally insecure**. After verifying the deployment works, rotate passwords immediately:

```bash
./scripts/rotate-secrets.sh
```

### Password Rotation

Passwords should be rotated regularly for security. The recommended policy is every **90 days**.

**Check rotation status:**
```bash
./scripts/validate-deployment.sh
# Shows: Last Rotated, Days Since, Next Rotation date
```

**Rotate passwords:**
```bash
./scripts/rotate-secrets.sh

# Options:
#   --dry-run      Show what would be done without making changes
#   --no-restart   Update passwords but don't restart Pentaho
#   --user USER    Only rotate a specific user (jcr_user, pentaho_user, hibuser)
```

**What rotation does:**
1. Generates new 24-character secure passwords
2. Updates SQL Server logins with `ALTER LOGIN`
3. Updates Vault secrets (creates new version)
4. Saves to `generated-passwords.json` for recovery
5. Restarts Pentaho to fetch new credentials

### Vault Architecture

```
┌─────────────────────────────────────────┐
│  Vault Server (vault:8200)              │
│  - File storage backend                 │
│  - Auto-initialized on first start      │
│  - KV v2 secrets engine                 │
└─────────────────────────────────────────┘
              │
              ├── secret/data/pentaho/mssql
              │   ├── sa_password
              │   ├── jcr_user / jcr_password
              │   ├── pentaho_user / pentaho_password
              │   ├── hibuser / hibuser_password
              │   ├── jdbc_url
              │   ├── passwords_source (default/rotated)
              │   └── rotated_at (timestamp)
              │
              └── AppRole: pentaho
                  └── Policy: pentaho-policy
```

### Secrets Storage

Database credentials are stored at `secret/data/pentaho/mssql`:

| Key | Description |
|-----|-------------|
| `sa_password` | SQL Server SA password |
| `jcr_user` / `jcr_password` | JackRabbit content repository credentials |
| `pentaho_user` / `pentaho_password` | Quartz scheduler credentials |
| `hibuser` / `hibuser_password` | Hibernate repository credentials |
| `jdbc_url` | JDBC connection URL |
| `passwords_source` | `default` (insecure) or `rotated` (secure) |
| `rotated_at` | Timestamp of last password rotation |

### Accessing Vault

```bash
# Get Vault status
docker compose exec vault vault status

# View stored secrets (requires root token)
docker compose exec vault vault kv get secret/pentaho/mssql

# Get root token from vault-keys.json
docker compose exec vault cat /vault/data/vault-keys.json | jq -r '.root_token'
```

### Docker Secrets Integration

The deployment also uses Docker secrets for initial database passwords:

```
secrets/
└── mssql_sa_password.txt    # SQL Server SA password
```

These are mounted at `/run/secrets/` inside containers and referenced via `*_FILE` environment variables.

## Security Features

### Resource Limits

All containers have CPU and memory limits to prevent resource exhaustion:

| Service | Memory Limit | CPU Limit | Memory Reservation |
|---------|-------------|-----------|-------------------|
| Vault | 512MB | 0.5 | 256MB |
| SQL Server | 4GB | 2 | 2GB |
| Pentaho | 6GB | 4 | 2GB |

### Log Rotation

All containers use JSON file logging with rotation:

| Service | Max Size | Max Files | Total Max |
|---------|----------|-----------|-----------|
| Vault | 50MB | 3 | 150MB |
| SQL Server | 100MB | 5 | 500MB |
| Pentaho | 200MB | 5 | 1GB |

### Graceful Shutdown

All services have `stop_grace_period: 60s` to allow clean shutdown.

## Database Management

### Backup Database

Create a backup of all Pentaho databases:

```bash
./scripts/backup-mssql.sh
```

Backups are saved to `backups/` directory with timestamp as `.bak` files.

### Restore Database

Restore from a backup file:

```bash
./scripts/restore-mssql.sh backups/pentaho-mssql-backup-YYYYMMDD-HHMMSS.bak
```

### Manual Database Access

```bash
# SQL Server CLI (sqlcmd)
docker exec -it pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd'

# Show databases
SELECT name FROM sys.databases;
GO

# Use specific database
USE jackrabbit;
GO

# Show tables
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;
GO
```

### Query Pentaho Databases

```bash
# Connect and query
docker exec -it pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd' -d jackrabbit -Q "SELECT COUNT(*) FROM dbo.JR_LOCAL_REVISIONS"
```

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker compose ps

# View logs
docker compose logs pentaho-server
docker compose logs mssql

# Restart specific service
docker compose restart pentaho-server
```

### Port Already in Use

```bash
# Find process using port 8090
sudo lsof -i :8090
# or
sudo netstat -tulpn | grep 8090

# Find process using SQL Server port
sudo lsof -i :1433

# Kill process or change port in .env
```

### SQL Server Connection Errors

```bash
# Verify SQL Server is healthy
docker compose ps mssql

# Check SQL Server logs
docker compose logs mssql

# Test connection
docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd' -Q "SELECT @@VERSION"

# Check if databases exist
docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd' -Q "SELECT name FROM sys.databases"
```

### SQL Server Password Complexity Error

If SQL Server fails to start with password error:

```bash
# Error: "The password does not meet SQL Server password policy requirements"

# Ensure password meets complexity requirements:
# - At least 8 characters
# - Contains uppercase, lowercase, numbers, and special characters
# Example: YourStr0ng!Passw0rd
```

### JDBC Connection Errors

Common JDBC connection issues:

1. **SSL/TLS Errors**: Ensure connection strings include `encrypt=false;trustServerCertificate=true`
2. **Driver Not Found**: Verify `mssql-jdbc-12.8.1.jre11.jar` is in `softwareOverride/1_drivers/tomcat/lib/`
3. **Timeout Errors**: SQL Server may take 30-60 seconds to start; check `docker compose logs mssql`

### Out of Memory

```bash
# Check container resource usage
docker stats

# Increase JVM memory in .env
PENTAHO_MAX_MEMORY=6144m

# Configure SQL Server memory limit
# Create mssql-config/mssql.conf:
# [memory]
# memorylimitmb = 4096

# Restart services
docker compose restart pentaho-server
docker compose restart mssql
```

### Permission Issues

```bash
# Pentaho runs as UID/GID 5000
# Check volume permissions
docker compose exec pentaho-server ls -la /opt/pentaho/pentaho-server/

# Reset permissions if needed
docker compose exec pentaho-server chown -R pentaho:pentaho /opt/pentaho/pentaho-server/
```

### Database Not Initialized

```bash
# Check if initialization container ran successfully
docker compose logs mssql-init

# If databases are missing, re-run initialization
docker compose up mssql-init

# Or recreate SQL Server volume
docker compose down -v
docker compose up -d mssql
docker compose up mssql-init
```

### Validate Deployment

Run comprehensive validation checks:

```bash
./scripts/validate-deployment.sh
```

## Production Hardening

### Security Checklist

- [ ] Change all default passwords (SQL Server SA, admin user)
- [ ] Use strong passwords meeting SQL Server complexity requirements
- [ ] Restrict SQL Server port exposure (remove from ports section)
- [ ] Configure firewall (UFW) for necessary ports only
- [ ] Enable SSL/TLS for Pentaho Server
- [ ] Configure SQL Server with encryption and certificates
- [ ] Use Docker secrets for sensitive data
- [ ] Set up regular automated backups
- [ ] Configure log rotation
- [ ] Update base images regularly
- [ ] Implement monitoring and alerting
- [ ] Use appropriate SQL Server edition for production (Standard/Enterprise)

### Change Default Passwords

**1. SQL Server SA Password**

Edit `.env`:
```bash
# Must meet complexity requirements
MSSQL_SA_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)!Aa1
```

Update database initialization scripts in `db_init_mssql/`:
```sql
-- Update password in connection strings if hardcoded
```

**2. Pentaho Admin Password**

After first login, change via Pentaho web interface or:

```bash
# Access Pentaho container
docker compose exec pentaho-server bash

# Use Pentaho encr tool to set new password
# Details in Pentaho documentation
```

### Restrict SQL Server Port

Edit `docker-compose.yml` - remove SQL Server port exposure:

```yaml
mssql:
  # Remove or comment out:
  # ports:
  #   - "${MSSQL_PORT:-1433}:1433"
```

### Configure Firewall (UFW)

```bash
# Enable UFW
sudo ufw enable

# Allow SSH
sudo ufw allow 22/tcp

# Allow Pentaho HTTP
sudo ufw allow 8090/tcp

# Check status
sudo ufw status
```

### SSL/TLS Configuration

**For Pentaho Server:**

1. Obtain SSL certificates (Let's Encrypt recommended)
2. Update `softwareOverride/4_others/tomcat/` with connector configuration
3. Mount certificates as volumes
4. Update `.env` with HTTPS port
5. Configure redirect from HTTP to HTTPS

**For SQL Server:**

1. Generate or obtain SSL certificate
2. Configure SQL Server to use the certificate:
   ```bash
   # Create mssql-config/mssql.conf
   [network]
   tlscert = /var/opt/mssql/ssl/server.crt
   tlskey = /var/opt/mssql/ssl/server.key
   tlsprotocols = 1.2
   forceencryption = 1
   ```
3. Update JDBC connection strings to use `encrypt=true`

### Docker Secrets (Swarm Mode)

For production with Docker Swarm:

```bash
# Create secrets
echo "YourStr0ng!Passw0rd" | docker secret create mssql_sa_password -

# Update docker-compose.yml to use secrets
# Reference: https://docs.docker.com/engine/swarm/secrets/
```

### SQL Server Licensing for Production

**Important**: The default `Developer` edition is NOT licensed for production use.

For production deployments:

1. Obtain SQL Server license (Standard or Enterprise)
2. Update `.env`:
   ```bash
   MSSQL_EDITION=Standard
   # or
   MSSQL_EDITION=Enterprise
   ```
3. Ensure compliance with Microsoft SQL Server licensing terms

## Backup and Recovery

### Automated Backups

Set up cron job for regular backups:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/Pentaho-Server-MSSQL/scripts/backup-mssql.sh

# Add weekly cleanup (keep last 30 days)
0 3 * * 0 find /path/to/Pentaho-Server-MSSQL/backups/ -name "*.bak" -mtime +30 -delete
```

### Disaster Recovery

**Complete System Recovery:**

1. Install Docker and Docker Compose on new system
2. Clone/copy this entire project directory
3. Place Pentaho ZIP in `docker/stagedArtifacts/`
4. Place MSSQL JDBC driver in `softwareOverride/1_drivers/tomcat/lib/`
5. Restore .env file with original configuration
6. Restore database from backup:
   ```bash
   ./scripts/restore-mssql.sh backups/your-backup.bak
   ```
7. Start services:
   ```bash
   docker compose up -d
   ```

### Volume Backups

Backup Docker volumes:

```bash
# Backup SQL Server volume
docker run --rm \
  -v pentaho_mssql_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/mssql-volume-$(date +%Y%m%d).tar.gz -C /data .

# Backup Pentaho solutions volume
docker run --rm \
  -v pentaho_solutions:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/solutions-volume-$(date +%Y%m%d).tar.gz -C /data .
```

### Manual Database Backup

Create individual database backups:

```bash
# Backup all Pentaho databases
for db in jackrabbit quartz hibernate pentaho_dilogs pentaho_operations_mart; do
  docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd' -Q "BACKUP DATABASE [$db] TO DISK = '/var/opt/mssql/backup/${db}_$(date +%Y%m%d).bak'"
done

# Copy backups from container
docker cp pentaho-mssql:/var/opt/mssql/backup/. ./backups/
```

## Useful Commands

### Service Management

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose stop

# Restart specific service
docker compose restart pentaho-server

# View service status
docker compose ps

# Remove all containers (keeps volumes)
docker compose down

# Remove all containers and volumes (DESTRUCTIVE!)
docker compose down -v
```

### Logs

```bash
# View all logs
docker compose logs

# Follow logs in real-time
docker compose logs -f

# View specific service logs
docker compose logs pentaho-server
docker compose logs mssql

# View initialization logs
docker compose logs mssql-init

# Last 100 lines
docker compose logs --tail=100 pentaho-server
```

### Shell Access

```bash
# Pentaho Server shell
docker compose exec pentaho-server bash

# SQL Server shell
docker compose exec mssql bash

# SQL Server CLI (sqlcmd) directly
docker compose exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd'
```

### Resource Monitoring

```bash
# Real-time resource usage
docker stats

# Disk usage
docker system df

# Volume details
docker volume ls
docker volume inspect pentaho_mssql_data
```

### SQL Server Specific Commands

```bash
# Check SQL Server version
docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd' -Q "SELECT @@VERSION"

# Check SQL Server edition
docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd' -Q "SELECT SERVERPROPERTY('Edition')"

# List all databases
docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd' -Q "SELECT name, database_id, create_date FROM sys.databases"

# Check database sizes
docker exec pentaho-mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P 'YourStr0ng!Passw0rd' -Q "SELECT DB_NAME(database_id) AS DatabaseName, (size * 8.0 / 1024) AS SizeMB FROM sys.master_files WHERE type = 0"
```

## Support and Resources

### Documentation

- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)
- [Docker Documentation](https://docs.docker.com/)
- [SQL Server 2022 Documentation](https://learn.microsoft.com/en-us/sql/sql-server/)
- [Microsoft JDBC Driver Documentation](https://learn.microsoft.com/en-us/sql/connect/jdbc/)

### Getting Help

- Check logs: `docker compose logs -f`
- Run validation: `./scripts/validate-deployment.sh`
- Review this README's Troubleshooting section
- Pentaho Community Forums
- Docker Community
- SQL Server Community

## License

This deployment configuration is provided as-is.

**Important Licensing Notes:**
- Pentaho Server requires appropriate licensing from Hitachi Vantara for enterprise features
- SQL Server Developer Edition is NOT licensed for production use
- For production, you must obtain appropriate SQL Server licensing (Standard or Enterprise)
- Consult Microsoft SQL Server licensing documentation for compliance requirements

## Contributing

This is a standalone deployment project. To modify:

1. Update configuration files in appropriate directories
2. Test changes thoroughly
3. Update documentation in this README
4. Create backup before making changes to running deployment

## Project Structure

```
Pentaho-Server-MSSQL/
├── README.md                    # This documentation file
├── CHANGELOG.md                 # Version history and changes
├── ARCHITECTURE.md              # Detailed system architecture
├── CONFIGURATION.md             # Configuration reference guide
├── TROUBLESHOOTING.md           # Extended troubleshooting guide
├── docker-compose.yml           # Docker Compose service definitions
├── Makefile                     # Convenience targets (make help)
├── deploy.sh                    # Automated deployment script
├── .env                         # Environment configuration (created from template)
├── .env.template                # Environment template with defaults
│
├── docker/                      # Docker build context
│   ├── Dockerfile               # Multi-stage Pentaho Server image build
│   ├── entrypoint/              # Container entrypoint scripts
│   │   └── docker-entrypoint.sh # Startup script (processes softwareOverride)
│   └── stagedArtifacts/         # Pentaho installation packages
│       └── pentaho-server-ee-11.0.0.0-237.zip
│
├── db_init_mssql/               # SQL Server initialization scripts
│   ├── 1_create_jcr_mssql.sql   # JackRabbit content repository
│   ├── 2_create_quartz_mssql.sql # Quartz scheduler
│   ├── 3_create_repository_mssql.sql # Hibernate repository
│   ├── 4_pentaho_dilogs_mssql.sql   # ETL logging
│   └── 5_pentaho_operations_mart_mssql.sql # Operations mart
│
├── mssql-config/                # SQL Server configuration
│   └── mssql.conf               # Server settings (memory, network, etc.)
│
├── softwareOverride/            # Pentaho configuration overrides
│   ├── README.md                # Override system documentation
│   ├── 1_drivers/               # JDBC drivers (MSSQL driver required)
│   │   └── tomcat/lib/
│   │       └── mssql-jdbc-12.8.1.jre11.jar
│   ├── 2_repository/            # Database configuration
│   │   ├── pentaho-solutions/system/
│   │   │   ├── hibernate/hibernate-settings.xml
│   │   │   ├── jackrabbit/repository.xml
│   │   │   └── scheduler-plugin/quartz/quartz.properties
│   │   └── tomcat/webapps/pentaho/META-INF/context.xml
│   ├── 3_security/              # Authentication settings
│   ├── 4_others/                # Tomcat and app configuration
│   └── 99_exchange/             # User data exchange
│
├── scripts/                     # Utility scripts
│   ├── backup-mssql.sh          # Database backup (.bak files)
│   ├── restore-mssql.sh         # Database restore
│   └── validate-deployment.sh   # Deployment validation
│
├── config/                      # User configuration (mounted volumes)
│   ├── .kettle/                 # PDI/Kettle configuration
│   └── .pentaho/                # Pentaho user settings
│
└── backups/                     # Database backup storage (.bak files)
```

### Key Files Explained

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Defines all services (pentaho-server, mssql, mssql-init), networks, and volumes |
| `docker/Dockerfile` | Multi-stage build using `debian:trixie-slim` with OpenJDK 21 |
| `docker/entrypoint/docker-entrypoint.sh` | Processes softwareOverride directories at startup |
| `.env` | Environment-specific configuration (ports, passwords, memory, SQL Server edition) |
| `deploy.sh` | Automated deployment with pre-flight checks |
| `Makefile` | Convenience commands (run `make help` for list) |
| `db_init_mssql/*.sql` | SQL Server database initialization scripts |
| `mssql-config/mssql.conf` | SQL Server configuration file |

### Important Configuration Files

**JDBC Connection Strings** (in `softwareOverride/2_repository/`):

All JDBC URLs must use the format:
```
jdbc:sqlserver://repository:1433;databaseName=<database>;encrypt=false;trustServerCertificate=true
```

Key files to configure:
- `pentaho-solutions/system/hibernate/hibernate-settings.xml`
- `pentaho-solutions/system/jackrabbit/repository.xml`
- `pentaho-solutions/system/scheduler-plugin/quartz/quartz.properties`
- `tomcat/webapps/pentaho/META-INF/context.xml`

## Recent Changes

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

### Version 1.2.0 (2026-01-16)

**Dynamic Password Generation:**
- Database user passwords (jcr_user, pentaho_user, hibuser) are now automatically generated
- Secure 24-character passwords with complexity requirements
- Passwords persisted in `/vault/data/generated-passwords.json` for consistency across restarts
- No more hardcoded default passwords for database users

**Security Improvements:**
- Root token and secrets no longer logged in plain text (masked output)
- Vault secrets verification added to validation script
- AppRole authentication tested during deployment validation
- Validation script displays all stored secrets for verification
- Vault automatically sealed after secrets verification (production best practice)

**Reliability Enhancements:**
- Retry logic with configurable attempts (30 retries, 2s interval) for Vault initialization
- Better error handling and progress output during startup
- Secrets verification confirms credentials are properly stored

**Vault Backup & Restore:**
- New `scripts/backup-vault.sh` - Creates timestamped backups of Vault credentials
- New `scripts/restore-vault.sh` - Restores Vault from backup with confirmation
- Backups include: vault-keys.json, approle-creds.json, generated-passwords.json

**Usage:**
```bash
# Backup Vault credentials
./scripts/backup-vault.sh

# Restore from backup
./scripts/restore-vault.sh backups/vault-backup-YYYYMMDD-HHMMSS.tar.gz
```

### Version 1.1.0 (2026-01-16)

**Security Enhancements:**
- Added HashiCorp Vault integration for secrets management
- Database credentials now stored in Vault instead of plain text
- AppRole authentication for Pentaho to retrieve secrets
- Docker secrets integration for SA password

**Resource Management:**
- Added CPU and memory limits to all containers
- Vault: 512MB RAM, 0.5 CPUs
- SQL Server: 4GB RAM, 2 CPUs
- Pentaho: 6GB RAM (configurable), 4 CPUs

**Reliability:**
- Added JSON log driver with rotation to all containers
- Added `stop_grace_period: 60s` for graceful shutdown
- Increased health check retries for Pentaho startup
- Added tmpfs for temporary directories

**New Files:**
- `vault/config/vault.hcl` - Vault server configuration
- `vault/policies/pentaho-policy.hcl` - Access policy
- `secrets/mssql_sa_password.txt` - Docker secrets file
- `scripts/vault-init.sh` - Vault initialization script
- `scripts/fetch-secrets.sh` - Secret retrieval helper

### Version 1.0.0 (2026-01-13)

**Database Changes:**
- Changed from MySQL 8.0 to Microsoft SQL Server 2022
- Added mssql-init container for automated database initialization
- Support for multiple SQL Server editions (Developer, Express, Standard, Enterprise)

**JDBC Driver:**
- Microsoft JDBC Driver for SQL Server (mssql-jdbc-12.8.1.jre11.jar) required
- Connection strings include `encrypt=false;trustServerCertificate=true`
- Driver must be manually downloaded and placed in `softwareOverride/1_drivers/tomcat/lib/`

**Configuration Updates:**
- All repository configurations updated for SQL Server syntax
- Port changed from 3306 to 1433
- Password requirements updated for SQL Server complexity rules
- Backup/restore scripts changed to use .bak format instead of .sql

**Docker Image:**
- Base image: `debian:trixie-slim` with OpenJDK 21 JRE
- No dependency on private container registries

**Accessing Logs:**
Use Docker's native logging instead of bind-mounted log files:
```bash
# View Pentaho Server logs
docker compose logs -f pentaho-server

# View SQL Server logs
docker compose logs -f mssql

# View initialization logs
docker compose logs mssql-init

# View last 100 lines
docker compose logs --tail=100 pentaho-server
```

---

**Project Version**: 1.2.0
**Pentaho Version**: 11.0.0.0-237
**SQL Server Version**: 2022 (Developer Edition)
**Last Updated**: 2026-01-16

For questions or issues with this deployment, refer to the Troubleshooting section or review the generated logs.
