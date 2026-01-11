# Pentaho Server 11 Docker Deployment for Ubuntu 24.04

Complete, standalone Docker Compose deployment for Pentaho Server 11.0.0.0-237 with MySQL repository on Ubuntu 24.04.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Manual Deployment](#manual-deployment)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Database Management](#database-management)
- [Troubleshooting](#troubleshooting)
- [Production Hardening](#production-hardening)
- [Backup and Recovery](#backup-and-recovery)

## Overview

This project provides a production-ready Docker Compose deployment for:

- **Pentaho Server 11.0.0.0-237** (Enterprise Edition)
- **MySQL 8.0** with Pentaho repository databases
- **Adminer** for database administration (optional)

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
- **Ports**: 8090 (HTTP), 8443 (HTTPS), 3306 (MySQL), 8050 (Adminer)

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

- **Adminer** (Database Admin): http://localhost:8050
  - Server: `repository`
  - Username: `root`
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

# Start Adminer (optional)
docker compose up -d adminer
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

# Adminer
ADMINER_PORT=8050
```

### MySQL Configuration

Customize `mysql-config/custom.cnf`:

```ini
[mysqld]
max_connections=200
innodb_buffer_pool_size=512M       # Adjust based on available RAM
```

### Pentaho Configuration Overrides

Files in `softwareOverride/` are automatically applied during container startup:

- `1_drivers/` - JDBC drivers and plugins
- `2_repository/` - Repository configurations (context.xml, hibernate, quartz)
- `3_security/` - Security settings
- `4_others/` - Tomcat and other configurations

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

┌─────────────────────────────────────────┐
│  adminer:8050                           │
│  - Web-based database admin             │
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
- [ ] Remove or disable Adminer service
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

### Remove Adminer (Production)

Edit `docker-compose.yml` - comment out or remove adminer service:

```yaml
# Comment out entire adminer service section
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

---

**Project Version**: 1.0.0
**Pentaho Version**: 11.0.0.0-237
**Last Updated**: 2026-01-11

For questions or issues with this deployment, refer to the Troubleshooting section or review the generated logs.
