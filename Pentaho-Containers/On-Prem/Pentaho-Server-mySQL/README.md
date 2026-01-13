# Pentaho Server 11 Docker Deployment for Ubuntu 24.04

Complete, standalone Docker Compose deployment for Pentaho Server 11.0.0.0-237 with MySQL repository on Ubuntu 24.04.

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
- **MySQL 8.0** with Pentaho repository databases

### Key Features

- Completely self-contained and portable
- Automated database initialization
- Health checks and proper startup ordering
- Persistent data volumes
- Easy backup and restore
- Production-ready configuration templates

## Prerequisites

### System Requirements

- **OS**: Ubuntu 24.04 LTS (also compatible with Ubuntu 22.04, 20.04)
- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 20GB+ available space
- **Ports**: 8090 (HTTP), 8443 (HTTPS), 3306 (MySQL)

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

## Quick Start

### 1. Prepare Pentaho Package

```bash
# Place your Pentaho package in the staged artifacts directory
cp /path/to/pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
```

### 2. Configure Environment (Optional)

```bash
# Create .env file from template
cp .env.template .env

# Edit .env to customize settings (optional)
nano .env
```

### 3. Deploy

```bash
# Run automated deployment script
chmod +x deploy.sh
./deploy.sh
```

The script will:
- Validate prerequisites
- Build the Pentaho Server image
- Start MySQL and initialize databases
- Start Pentaho Server
- Display access URLs

### 4. Access Services

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
# Start MySQL first
docker compose up -d mysql

# Wait for MySQL to be ready (check logs)
docker compose logs -f mysql

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

# MySQL Configuration
MYSQL_ROOT_PASSWORD=password        # Change for production!
MYSQL_PORT=3306

# Pentaho Server Ports
PENTAHO_HTTP_PORT=8090
PENTAHO_HTTPS_PORT=8443

# JVM Memory Settings
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m           # Adjust based on available RAM

# License (optional for EE features)
LICENSE_URL=http://your-server/pentaho-ee-license.lic
```

### MySQL Configuration

Customize `mysql-config/custom.cnf`:

```ini
[mysqld]
max_connections=200
innodb_buffer_pool_size=512M       # Adjust based on available RAM
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
│   │   └── mysql-connector-j-8.3.0.jar   # MySQL 8.x JDBC driver
│   └── pentaho-solutions/drivers/        # Big data drivers (.kar files)
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

### MySQL JDBC Driver

The MySQL Connector/J driver is included at:
```
softwareOverride/1_drivers/tomcat/lib/mysql-connector-j-8.3.0.jar
```

This driver is required for Pentaho to connect to the MySQL repository. Version 8.3.0 is compatible with MySQL 8.0.

**To upgrade the driver:**
1. Download new version from [Maven Central](https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/)
2. Replace the JAR file in `softwareOverride/1_drivers/tomcat/lib/`
3. Rebuild the container: `docker compose build --no-cache pentaho-server`

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
│  pentaho-server:8090                    │
│  - Pentaho Server 11.0.0.0-237          │
│  - Tomcat 9                             │
│  - OpenJDK 21                           │
└─────────────┬───────────────────────────┘
              │ JDBC Connection
              ▼
┌─────────────────────────────────────────┐
│  mysql:3306 (hostname: repository)      │
│  - MySQL 8.0                            │
│  - 5 Pentaho Databases:                 │
│    • jackrabbit (JCR)                   │
│    • quartz (Scheduler)                 │
│    • hibernate (Repository)             │
│    • Logging Tables                     │
│    • Operations Mart                    │
└─────────────────────────────────────────┘

```

### Data Persistence

Named Docker volumes ensure data persists across container restarts:

- `pentaho_mysql_data` - MySQL databases
- `pentaho_solutions` - Pentaho solutions repository
- `pentaho_data` - Pentaho data files

### Networking

Bridge network `pentaho-net` (172.28.0.0/16) provides:

- Service discovery (containers can reach each other by hostname)
- Network isolation from host
- Custom subnet to avoid VPN conflicts

## Database Management

### Backup Database

Create a compressed backup of all Pentaho databases:

```bash
./scripts/backup-mysql.sh
```

Backups are saved to `backups/` directory with timestamp.

### Restore Database

Restore from a backup file:

```bash
./scripts/restore-mysql.sh backups/pentaho-mysql-backup-YYYYMMDD-HHMMSS.sql.gz
```

### Manual Database Access

```bash
# MySQL CLI
docker exec -it pentaho-mysql mysql -uroot -ppassword

# Show databases
SHOW DATABASES;

# Use specific database
USE jackrabbit;
SHOW TABLES;
```

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker compose ps

# View logs
docker compose logs pentaho-server
docker compose logs mysql

# Restart specific service
docker compose restart pentaho-server
```

### Port Already in Use

```bash
# Find process using port 8090
sudo lsof -i :8090
# or
sudo netstat -tulpn | grep 8090

# Kill process or change port in .env
```

### MySQL Connection Errors

```bash
# Verify MySQL is healthy
docker compose ps mysql

# Check MySQL logs
docker compose logs mysql

# Test connection
docker exec pentaho-mysql mysqladmin ping -uroot -ppassword
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

### Database Not Initialized

```bash
# Check if initialization scripts ran
docker compose logs mysql | grep "db_init_mysql"

# If databases are missing, recreate MySQL volume
docker compose down -v
docker compose up -d mysql
```

### Validate Deployment

Run comprehensive validation checks:

```bash
./scripts/validate-deployment.sh
```

## Production Hardening

### Security Checklist

- [ ] Change all default passwords (MySQL root, admin user)
- [ ] Restrict MySQL port exposure (remove from ports section)
- [ ] Configure firewall (UFW) for necessary ports only
- [ ] Enable SSL/TLS for Pentaho Server
- [ ] Use Docker secrets for sensitive data
- [ ] Set up regular automated backups
- [ ] Configure log rotation
- [ ] Update base images regularly
- [ ] Implement monitoring and alerting

### Change Default Passwords

**1. MySQL Root Password**

Edit `.env`:
```bash
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
```

Update database initialization scripts in `db_init_mysql/`:
```sql
-- Replace 'password' with your strong password in all 5 SQL files
```

**2. Pentaho Admin Password**

After first login, change via Pentaho web interface or:

```bash
# Access Pentaho container
docker compose exec pentaho-server bash

# Use Pentaho encr tool to set new password
# Details in Pentaho documentation
```

### Restrict MySQL Port

Edit `docker-compose.yml` - remove MySQL port exposure:

```yaml
mysql:
  # Remove or comment out:
  # ports:
  #   - "${MYSQL_PORT:-3306}:3306"
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
echo "strong_password" | docker secret create mysql_root_password -

# Update docker-compose.yml to use secrets
# Reference: https://docs.docker.com/engine/swarm/secrets/
```

## Backup and Recovery

### Automated Backups

Set up cron job for regular backups:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/pentaho-mysql-ubuntu/scripts/backup-mysql.sh

# Add weekly cleanup (keep last 30 days)
0 3 * * 0 find /path/to/pentaho-mysql-ubuntu/backups/ -name "*.sql.gz" -mtime +30 -delete
```

### Disaster Recovery

**Complete System Recovery:**

1. Install Docker and Docker Compose on new system
2. Clone/copy this entire project directory
3. Place Pentaho ZIP in `docker/stagedArtifacts/`
4. Restore .env file with original configuration
5. Restore database from backup:
   ```bash
   ./scripts/restore-mysql.sh backups/your-backup.sql.gz
   ```
6. Start services:
   ```bash
   docker compose up -d
   ```

### Volume Backups

Backup Docker volumes:

```bash
# Backup MySQL volume
docker run --rm \
  -v pentaho_mysql_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/mysql-volume-$(date +%Y%m%d).tar.gz -C /data .

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

# Last 100 lines
docker compose logs --tail=100 pentaho-server
```

### Shell Access

```bash
# Pentaho Server shell
docker compose exec pentaho-server bash

# MySQL shell
docker compose exec mysql bash

# MySQL CLI directly
docker compose exec mysql mysql -uroot -ppassword
```

### Resource Monitoring

```bash
# Real-time resource usage
docker stats

# Disk usage
docker system df

# Volume details
docker volume ls
docker volume inspect pentaho_mysql_data
```

## Support and Resources

### Documentation

- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)
- [Docker Documentation](https://docs.docker.com/)
- [MySQL 8.0 Reference](https://dev.mysql.com/doc/refman/8.0/en/)

### Getting Help

- Check logs: `docker compose logs -f`
- Run validation: `./scripts/validate-deployment.sh`
- Review this README's Troubleshooting section
- Pentaho Community Forums
- Docker Community

## License

This deployment configuration is provided as-is. Pentaho Server requires appropriate licensing from Hitachi Vantara for enterprise features.

## Contributing

This is a standalone deployment project. To modify:

1. Update configuration files in appropriate directories
2. Test changes thoroughly
3. Update documentation in this README
4. Create backup before making changes to running deployment

## Project Structure

```
pentaho-mysql-ubuntu/
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
├── db_init_mysql/               # MySQL initialization scripts
│   ├── 1_create_jcr_mysql.sql   # JackRabbit content repository
│   ├── 2_create_quartz_mysql.sql # Quartz scheduler
│   ├── 3_create_repository_mysql.sql # Hibernate repository
│   ├── 4_pentaho_logging_mysql.sql # Audit logging
│   └── 5_pentaho_mart_mysql.sql # Operations mart
│
├── mysql-config/                # MySQL configuration
│   └── custom.cnf               # Performance tuning settings
│
├── softwareOverride/            # Pentaho configuration overrides
│   ├── README.md                # Override system documentation
│   ├── 1_drivers/               # JDBC drivers (MySQL connector included)
│   ├── 2_repository/            # Database configuration
│   ├── 3_security/              # Authentication settings
│   ├── 4_others/                # Tomcat and app configuration
│   └── 99_exchange/             # User data exchange
│
├── scripts/                     # Utility scripts
│   ├── backup-mysql.sh          # Database backup
│   ├── restore-mysql.sh         # Database restore
│   └── validate-deployment.sh   # Deployment validation
│
├── config/                      # User configuration (mounted volumes)
│   ├── .kettle/                 # PDI/Kettle configuration
│   └── .pentaho/                # Pentaho user settings
│
└── backups/                     # Database backup storage
```

### Key Files Explained

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Defines all services, networks, and volumes |
| `docker/Dockerfile` | Multi-stage build using `debian:trixie-slim` with OpenJDK 21 |
| `docker/entrypoint/docker-entrypoint.sh` | Processes softwareOverride directories at startup |
| `.env` | Environment-specific configuration (ports, passwords, memory) |
| `deploy.sh` | Automated deployment with pre-flight checks |
| `Makefile` | Convenience commands (run `make help` for list) |

## Recent Changes

See [CHANGELOG.md](CHANGELOG.md) for detailed version history.

### Version 1.0.0 (2026-01-12)

**Docker Image Changes:**
- Base image changed from Hitachi Vantara registry to `debian:trixie-slim`
- Uses official Debian packages and OpenJDK 21 JRE
- No dependency on private container registries

**Configuration Updates:**
- MySQL JDBC driver (8.3.0) added to `softwareOverride/1_drivers/tomcat/lib/`
- Entrypoint script relocated to `docker/entrypoint/docker-entrypoint.sh`
- Logs volume commented out in docker-compose.yml to prevent permission issues

**Accessing Logs:**
Instead of bind-mounted log files, use Docker's native logging:
```bash
# View Pentaho Server logs
docker compose logs -f pentaho-server

# View last 100 lines
docker compose logs --tail=100 pentaho-server

# View all service logs
docker compose logs -f
```

---

**Project Version**: 1.0.0
**Pentaho Version**: 11.0.0.0-237
**Last Updated**: 2026-01-12

For questions or issues with this deployment, refer to the Troubleshooting section or review the generated logs.
