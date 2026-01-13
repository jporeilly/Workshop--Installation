# Pentaho Server 11 Docker Deployment (Oracle Repository)

Complete, standalone Docker Compose deployment for Pentaho Server 11.0.0.0-237 with Oracle Database 23c Free repository on Ubuntu 24.04.

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
- **Oracle Database 23c Free** with Pentaho repository schemas

### Key Features

- Completely self-contained and portable
- Automated database initialization via init scripts
- Health checks and proper startup ordering
- Persistent data volumes
- Easy backup and restore using Oracle Data Pump
- Production-ready configuration templates

## Prerequisites

### System Requirements

- **OS**: Ubuntu 24.04 LTS (also compatible with Ubuntu 22.04, 20.04)
- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB recommended (Oracle requires 2GB minimum)
- **Disk**: 15GB+ available space (Oracle needs ~8GB)
- **Ports**: 8090 (HTTP), 8443 (HTTPS), 1521 (Oracle)

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

4. **Oracle JDBC Driver**
   - Download Oracle JDBC Driver (ojdbc11.jar) from [Oracle](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html)
   - Place in `softwareOverride/1_drivers/tomcat/lib/`

## Quick Start

### 1. Prepare Pentaho Package

```bash
# Place your Pentaho package in the staged artifacts directory
cp /path/to/pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
```

### 2. Download Oracle JDBC Driver

```bash
# Download from Oracle and place in drivers directory
cp ojdbc11.jar softwareOverride/1_drivers/tomcat/lib/
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
- Start Oracle Database and initialize schemas
- Start Pentaho Server
- Display access URLs

### 5. Access Services

Once deployment completes:

- **Pentaho Server**: http://localhost:8090/pentaho
  - Username: `admin`
  - Password: `password`

- **Oracle Database**: localhost:1521
  - Service: `FREEPDB1`
  - Users: `jcr_user`, `pentaho_user`, `hibuser`

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
# Start Oracle first (takes 2-5 minutes on first run)
docker compose up -d oracle

# Wait for Oracle to be ready (check logs)
docker compose logs -f oracle

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

# Oracle Configuration
ORACLE_PASSWORD=password            # Change for production!
ORACLE_PORT=1521

# Pentaho Server Ports
PENTAHO_HTTP_PORT=8090
PENTAHO_HTTPS_PORT=8443

# JVM Memory Settings
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m            # Adjust based on available RAM

# License (optional for EE features)
LICENSE_URL=http://your-server/pentaho-ee-license.lic
```

### Oracle Free Edition Limitations

The Oracle Free (23c) container has the following limitations:

- 12GB user data limit
- 2GB RAM limit
- 2 CPU threads

For production workloads with larger data requirements, consider Oracle Enterprise Edition.

### Database Schemas

The Oracle deployment creates three database users (schemas):

| User | Purpose |
|------|---------|
| `jcr_user` | Jackrabbit content repository |
| `pentaho_user` | Quartz scheduler tables |
| `hibuser` | Hibernate metadata, logging, operations mart |

### Pentaho Configuration Overrides

Files in `softwareOverride/` are automatically applied during container startup. See the [Software Override System](#software-override-system) section for detailed documentation.

## Software Override System

The `softwareOverride/` directory provides a powerful mechanism to customize Pentaho Server without modifying the core installation. Files are copied into the Pentaho installation during container startup, processed in alphabetical order by directory name.

### Directory Structure

```
softwareOverride/
├── 1_drivers/           # JDBC drivers and data connectors
│   ├── tomcat/lib/
│   │   └── ojdbc11.jar              # Oracle JDBC driver (required)
│   └── pentaho-solutions/drivers/    # Big data drivers (.kar files)
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

### Oracle JDBC Driver

The Oracle JDBC Driver is required at:
```
softwareOverride/1_drivers/tomcat/lib/ojdbc11.jar
```

This driver is required for Pentaho to connect to the Oracle repository.

**To download the driver:**
1. Visit [Oracle JDBC Driver Download](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html)
2. Download ojdbc11.jar (for JDK 11+)
3. Place in `softwareOverride/1_drivers/tomcat/lib/`
4. Rebuild the container: `docker compose build --no-cache pentaho-server`

### Adding Custom Configurations

1. Create matching directory structure under `softwareOverride/`
2. Place files with paths matching the Pentaho installation structure
3. Rebuild container: `docker compose build pentaho-server`
4. Restart: `docker compose up -d pentaho-server`

### Skipping Directories

Create a `.ignore` file in any directory to skip processing during startup.

## Architecture

### Services

```
┌─────────────────────────────────────────┐
│  pentaho-server:8090                    │
│  - Pentaho Server 11.0.0.0-237          │
│  - Tomcat 9                             │
│  - OpenJDK 21                           │
└─────────────┬───────────────────────────┘
              │ JDBC Connection (port 1521)
              │ Service: FREEPDB1
              ▼
┌─────────────────────────────────────────┐
│  oracle:1521 (hostname: repository)     │
│  - Oracle Database 23c Free             │
│  - 3 Pentaho Schemas:                   │
│    • jcr_user (JCR)                     │
│    • pentaho_user (Scheduler)           │
│    • hibuser (Repository/Logging/Mart)  │
└─────────────────────────────────────────┘
```

### Data Persistence

Named Docker volumes ensure data persists across container restarts:

- `pentaho_oracle_data` - Oracle database files
- `pentaho_solutions` - Pentaho solutions repository
- `pentaho_data` - Pentaho data files

### Networking

Bridge network `pentaho-net` (172.28.0.0/16) provides:

- Service discovery (containers can reach each other by hostname)
- Network isolation from host
- Custom subnet to avoid VPN conflicts

## Database Management

### Backup Database

Create a backup using Oracle Data Pump:

```bash
./scripts/backup-oracle.sh
```

Backups are saved to `backups/` directory as `.dmp` files.

### Restore Database

Restore from a backup file:

```bash
./scripts/restore-oracle.sh backups/pentaho_backup_YYYYMMDD.dmp
```

### Manual Database Access

```bash
# SQL*Plus CLI
docker exec -it pentaho-oracle sqlplus hibuser/password@//localhost:1521/FREEPDB1

# Show tables
SELECT table_name FROM user_tables;

# Check tablespace usage
SELECT tablespace_name, ROUND(SUM(bytes)/1024/1024,2) AS size_mb
FROM dba_data_files GROUP BY tablespace_name;
```

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker compose ps

# View logs
docker compose logs pentaho-server
docker compose logs oracle

# Restart specific service
docker compose restart pentaho-server
```

### Port Already in Use

```bash
# Find process using port 8090
sudo lsof -i :8090

# Find process using Oracle port
sudo lsof -i :1521

# Kill process or change port in .env
```

### Oracle Not Starting

```bash
# Check Oracle logs
docker compose logs oracle

# Ensure sufficient disk space (Oracle needs ~8GB)
df -h

# Oracle initialization on first startup takes 2-5 minutes
```

### Oracle Connection Errors

```bash
# Verify Oracle is healthy
docker compose ps oracle

# Test connection
docker exec pentaho-oracle sqlplus -s hibuser/password@//localhost:1521/FREEPDB1 <<< "SELECT 1 FROM DUAL;"

# Check if schemas exist
docker exec pentaho-oracle sqlplus -s sys/password@//localhost:1521/FREEPDB1 as sysdba <<< "SELECT username FROM dba_users WHERE username IN ('JCR_USER','PENTAHO_USER','HIBUSER');"
```

### JDBC Driver Missing

```bash
# Verify Oracle JDBC driver exists
ls -la softwareOverride/1_drivers/tomcat/lib/ojdbc*.jar

# If missing, download from Oracle website and rebuild
docker compose build --no-cache pentaho-server
```

### Out of Memory

```bash
# Check container resource usage
docker stats

# Increase JVM memory in .env
PENTAHO_MAX_MEMORY=6144m

# Restart Pentaho
docker compose restart pentaho-server
```

### Permission Issues

```bash
# Pentaho runs as UID/GID 5000
# Check volume permissions
docker compose exec pentaho-server ls -la /opt/pentaho/pentaho-server/

# Reset permissions if needed
docker compose exec pentaho-server chown -R pentaho:pentaho /opt/pentaho/pentaho-server/
```

### Validate Deployment

Run comprehensive validation checks:

```bash
./scripts/validate-deployment.sh
```

## Production Hardening

### Security Checklist

- [ ] Change all default passwords (Oracle, admin user)
- [ ] Restrict Oracle port exposure (remove from ports section)
- [ ] Configure firewall (UFW) for necessary ports only
- [ ] Enable SSL/TLS for Pentaho Server
- [ ] Use Docker secrets for sensitive data
- [ ] Set up regular automated backups
- [ ] Configure log rotation
- [ ] Update base images regularly
- [ ] Implement monitoring and alerting
- [ ] Consider Oracle Enterprise Edition for production

### Change Default Passwords

**1. Oracle Password**

Edit `.env`:
```bash
ORACLE_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-24)
```

Update database initialization scripts in `db_init_oracle/`.

**2. Pentaho Admin Password**

After first login, change via Pentaho web interface.

### Restrict Oracle Port

Edit `docker-compose.yml` - remove Oracle port exposure:

```yaml
oracle:
  # Remove or comment out:
  # ports:
  #   - "${ORACLE_PORT:-1521}:1521"
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

1. Obtain SSL certificates (Let's Encrypt recommended)
2. Update `softwareOverride/4_others/tomcat/` with connector configuration
3. Mount certificates as volumes
4. Update `.env` with HTTPS port
5. Configure redirect from HTTP to HTTPS

### Docker Secrets (Swarm Mode)

For production with Docker Swarm:

```bash
# Create secrets
echo "strong_password" | docker secret create oracle_password -

# Update docker-compose.yml to use secrets
```

## Backup and Recovery

### Automated Backups

Set up cron job for regular backups:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/Pentaho-Server-Oracle/scripts/backup-oracle.sh

# Add weekly cleanup (keep last 30 days)
0 3 * * 0 find /path/to/Pentaho-Server-Oracle/backups/ -name "*.dmp" -mtime +30 -delete
```

### Disaster Recovery

**Complete System Recovery:**

1. Install Docker and Docker Compose on new system
2. Clone/copy this entire project directory
3. Place Pentaho ZIP in `docker/stagedArtifacts/`
4. Place Oracle JDBC driver in `softwareOverride/1_drivers/tomcat/lib/`
5. Restore .env file with original configuration
6. Restore database from backup:
   ```bash
   ./scripts/restore-oracle.sh backups/your-backup.dmp
   ```
7. Start services:
   ```bash
   docker compose up -d
   ```

### Volume Backups

Backup Docker volumes:

```bash
# Backup Oracle volume
docker run --rm \
  -v pentaho_oracle_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/oracle-volume-$(date +%Y%m%d).tar.gz -C /data .

# Backup Pentaho solutions volume
docker run --rm \
  -v pentaho_solutions:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/solutions-volume-$(date +%Y%m%d).tar.gz -C /data .
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
docker compose logs oracle

# Last 100 lines
docker compose logs --tail=100 pentaho-server
```

### Shell Access

```bash
# Pentaho Server shell
docker compose exec pentaho-server bash

# Oracle shell
docker compose exec oracle bash

# SQL*Plus directly
docker compose exec oracle sqlplus hibuser/password@//localhost:1521/FREEPDB1
```

### Resource Monitoring

```bash
# Real-time resource usage
docker stats

# Disk usage
docker system df

# Volume details
docker volume ls
docker volume inspect pentaho_oracle_data
```

## Support and Resources

### Documentation

- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)
- [Docker Documentation](https://docs.docker.com/)
- [Oracle Database 23c Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/23/)

### Getting Help

- Check logs: `docker compose logs -f`
- Run validation: `./scripts/validate-deployment.sh`
- Review this README's Troubleshooting section
- Pentaho Community Forums
- Docker Community

## License

This deployment configuration is provided as-is.

**Important Licensing Notes:**
- Pentaho Server requires appropriate licensing from Hitachi Vantara for enterprise features
- Oracle Free Edition has data and resource limitations
- For production, consider Oracle Standard or Enterprise Edition with appropriate licensing

## Contributing

This is a standalone deployment project. To modify:

1. Update configuration files in appropriate directories
2. Test changes thoroughly
3. Update documentation in this README
4. Create backup before making changes to running deployment

## Project Structure

```
Pentaho-Server-Oracle/
├── README.md                    # This documentation file
├── QUICKSTART.md                # Quick start guide
├── CONFIGURATION.md             # Configuration reference guide
├── PROJECT_SUMMARY.md           # Project summary
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
├── db_init_oracle/              # Oracle initialization scripts
│   ├── 01_create_users.sql      # Create database users/schemas
│   ├── 02_create_jcr_oracle.sql # JackRabbit content repository
│   ├── 03_create_quartz_oracle.sql # Quartz scheduler
│   └── 04_create_repository_oracle.sql # Hibernate repository
│
├── oracle-config/               # Oracle configuration
│   └── init.ora                 # Oracle initialization parameters
│
├── softwareOverride/            # Pentaho configuration overrides
│   ├── README.md                # Override system documentation
│   ├── 1_drivers/               # JDBC drivers (ojdbc11.jar required)
│   ├── 2_repository/            # Database configuration
│   ├── 3_security/              # Authentication settings
│   ├── 4_others/                # Tomcat and app configuration
│   └── 99_exchange/             # User data exchange
│
├── scripts/                     # Utility scripts
│   ├── backup-oracle.sh         # Database backup (Data Pump)
│   ├── restore-oracle.sh        # Database restore
│   └── validate-deployment.sh   # Deployment validation
│
├── config/                      # User configuration (mounted volumes)
│   ├── .kettle/                 # PDI/Kettle configuration
│   └── .pentaho/                # Pentaho user settings
│
└── backups/                     # Database backup storage (.dmp files)
```

### Key Files Explained

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Defines all services (pentaho-server, oracle), networks, and volumes |
| `docker/Dockerfile` | Multi-stage build using `debian:trixie-slim` with OpenJDK 21 |
| `docker/entrypoint/docker-entrypoint.sh` | Processes softwareOverride directories at startup |
| `.env` | Environment-specific configuration (ports, passwords, memory) |
| `deploy.sh` | Automated deployment with pre-flight checks |
| `Makefile` | Convenience commands (run `make help` for list) |
| `db_init_oracle/*.sql` | Oracle database initialization scripts |

## Recent Changes

### Version 1.0.0 (2026-01-13)

**Docker Image Changes:**
- Base image: `debian:trixie-slim` with OpenJDK 21 JRE
- No dependency on private container registries

**Oracle Configuration:**
- Oracle Database 23c Free edition
- Three separate schemas for Pentaho components
- Data Pump for backup/restore operations

**JDBC Driver:**
- Oracle JDBC Driver (ojdbc11.jar) required
- Driver must be manually downloaded from Oracle website

**Accessing Logs:**
Use Docker's native logging:
```bash
# View Pentaho Server logs
docker compose logs -f pentaho-server

# View Oracle logs
docker compose logs -f oracle

# View last 100 lines
docker compose logs --tail=100 pentaho-server
```

---

**Project Version**: 1.0.0
**Pentaho Version**: 11.0.0.0-237
**Oracle Version**: 23c Free
**Last Updated**: 2026-01-13

For questions or issues with this deployment, refer to the Troubleshooting section or review the generated logs.
