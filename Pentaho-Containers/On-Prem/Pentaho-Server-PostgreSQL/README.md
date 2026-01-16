# Pentaho Server 11 Docker Deployment (PostgreSQL)

Complete, standalone Docker Compose deployment for Pentaho Server 11.0.0.0-237 with PostgreSQL 15 repository on Ubuntu 24.04.

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
- **PostgreSQL 15** with Pentaho repository databases

### Key Features

- Completely self-contained and portable
- Automated database initialization
- Health checks and proper startup ordering
- Persistent data volumes
- Easy backup and restore
- Production-ready configuration templates
- PostgreSQL JDBC driver included
- **HashiCorp Vault** for secrets management
- **Read-only containers** with tmpfs mounts for security
- **Resource limits** (CPU/memory) for stability
- **Log rotation** to prevent disk exhaustion

## Prerequisites

### System Requirements

- **OS**: Ubuntu 24.04 LTS (also compatible with Ubuntu 22.04, 20.04)
- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 10GB+ available space
- **Ports**: 8090 (HTTP), 8443 (HTTPS), 5432 (PostgreSQL), 8200 (Vault)

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
- Start PostgreSQL and initialize databases
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
# Start PostgreSQL first
docker compose up -d postgres

# Wait for PostgreSQL to be ready (check logs)
docker compose logs -f postgres

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

# PostgreSQL Configuration
POSTGRES_PASSWORD=password          # Change for production!
POSTGRES_PORT=5432

# Pentaho Server Ports
PENTAHO_HTTP_PORT=8090
PENTAHO_HTTPS_PORT=8443

# JVM Memory Settings
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m            # Adjust based on available RAM

# License (optional for EE features)
LICENSE_URL=http://your-server/pentaho-ee-license.lic
```

### PostgreSQL Configuration

Customize `postgres-config/custom.conf`:

```conf
# Connection limits
max_connections = 200

# Memory (adjust based on available RAM)
shared_buffers = 256MB
effective_cache_size = 768MB
work_mem = 16MB

# Performance
random_page_cost = 1.1
effective_io_concurrency = 200
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
│   │   └── postgresql-42.x.x.jar    # PostgreSQL JDBC driver (included)
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

### PostgreSQL JDBC Driver

The PostgreSQL JDBC driver is included in the Pentaho distribution. If you need to upgrade:

1. Download from [Maven Central](https://repo1.maven.org/maven2/org/postgresql/postgresql/)
2. Place in `softwareOverride/1_drivers/tomcat/lib/`
3. Rebuild the container: `docker compose build --no-cache pentaho-server`

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
              │ JDBC Connection (port 5432)
              ▼
┌─────────────────────────────────────────┐
│  postgres:5432 (hostname: repository)   │
│  - PostgreSQL 15 (read-only container)  │
│  - Resource Limits: 2GB RAM, 2 CPUs     │
│  - 3 Pentaho Databases:                 │
│    • jackrabbit (JCR)                   │
│    • quartz (Scheduler)                 │
│    • hibernate (Repository/Logging)     │
└─────────────────────────────────────────┘
```

### Data Persistence

Named Docker volumes ensure data persists across container restarts:

- `vault_data` - Vault data and unseal keys
- `pentaho_postgres_data` - PostgreSQL databases
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

### Vault Architecture

```
┌─────────────────────────────────────────┐
│  Vault Server (vault:8200)              │
│  - File storage backend                 │
│  - Auto-initialized on first start      │
│  - KV v2 secrets engine                 │
└─────────────────────────────────────────┘
              │
              ├── secret/data/pentaho/postgres
              │   ├── postgres_password
              │   ├── pentaho_user
              │   ├── pentaho_password
              │   └── jdbc_url
              │
              └── AppRole: pentaho
                  └── Policy: pentaho-policy
```

### Secrets Storage

Database credentials are stored at `secret/data/pentaho/postgres`:

| Key | Description |
|-----|-------------|
| `postgres_password` | PostgreSQL superuser password |
| `pentaho_user` | Pentaho database username |
| `pentaho_password` | Pentaho database password |
| `jdbc_url` | JDBC connection URL |

### Accessing Vault

```bash
# Get Vault status
docker compose exec vault vault status

# View stored secrets (requires root token)
docker compose exec vault vault kv get secret/pentaho/postgres

# Get root token from vault-keys.json
docker compose exec vault cat /vault/data/vault-keys.json | jq -r '.root_token'
```

### Docker Secrets Integration

The deployment also uses Docker secrets for initial database passwords:

```
secrets/
└── postgres_password.txt    # PostgreSQL password
```

## Security Features

### Read-Only Containers

Database containers run in read-only mode with explicit tmpfs mounts:

**PostgreSQL:**
- `/tmp` - Temporary files (256MB)
- `/var/run/postgresql` - Socket directory (64MB)

**Pentaho Server:**
- `/tmp` - Temporary files (512MB)
- `/opt/pentaho/pentaho-server/tomcat/temp` - Tomcat temp (256MB)
- `/opt/pentaho/pentaho-server/tomcat/work` - Tomcat work (256MB)

### Resource Limits

All containers have CPU and memory limits:

| Service | Memory Limit | CPU Limit | Memory Reservation |
|---------|-------------|-----------|-------------------|
| Vault | 512MB | 0.5 | 256MB |
| PostgreSQL | 2GB | 2 | 512MB |
| Pentaho | 6GB | 4 | 2GB |

### Log Rotation

All containers use JSON file logging with rotation:

| Service | Max Size | Max Files | Total Max |
|---------|----------|-----------|-----------|
| Vault | 50MB | 3 | 150MB |
| PostgreSQL | 100MB | 5 | 500MB |
| Pentaho | 200MB | 5 | 1GB |

### Graceful Shutdown

All services have `stop_grace_period: 60s` to allow clean shutdown.

## Database Management

### Backup Database

Create a compressed backup of all Pentaho databases:

```bash
./scripts/backup-postgres.sh
```

Backups are saved to `backups/` directory with timestamp.

### Restore Database

Restore from a backup file:

```bash
./scripts/restore-postgres.sh backups/pentaho-postgres-backup-YYYYMMDD-HHMMSS.sql.gz
```

### Manual Database Access

```bash
# PostgreSQL CLI (psql)
docker exec -it pentaho-postgres psql -U postgres

# List databases
\l

# Connect to specific database
\c jackrabbit

# List tables
\dt
```

## Troubleshooting

### Container Won't Start

```bash
# Check container status
docker compose ps

# View logs
docker compose logs pentaho-server
docker compose logs postgres

# Restart specific service
docker compose restart pentaho-server
```

### Port Already in Use

```bash
# Find process using port 8090
sudo lsof -i :8090

# Find process using PostgreSQL port
sudo lsof -i :5432

# Kill process or change port in .env
```

### PostgreSQL Connection Errors

```bash
# Verify PostgreSQL is healthy
docker compose ps postgres

# Check PostgreSQL logs
docker compose logs postgres

# Test connection
docker exec pentaho-postgres pg_isready -U postgres
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
docker compose logs postgres | grep "db_init_postgres"

# If databases are missing, recreate PostgreSQL volume
docker compose down -v
docker compose up -d postgres
```

### Validate Deployment

Run comprehensive validation checks:

```bash
./scripts/validate-deployment.sh
```

## Production Hardening

### Security Checklist

- [ ] Change all default passwords (PostgreSQL, admin user)
- [ ] Restrict PostgreSQL port exposure (remove from ports section)
- [ ] Configure firewall (UFW) for necessary ports only
- [ ] Enable SSL/TLS for Pentaho Server
- [ ] Use Docker secrets for sensitive data
- [ ] Set up regular automated backups
- [ ] Configure log rotation
- [ ] Update base images regularly
- [ ] Implement monitoring and alerting

### Change Default Passwords

**1. PostgreSQL Password**

Edit `.env`:
```bash
POSTGRES_PASSWORD=$(openssl rand -base64 32)
```

Update database initialization scripts in `db_init_postgres/`.

**2. Pentaho Admin Password**

After first login, change via Pentaho web interface.

### Restrict PostgreSQL Port

Edit `docker-compose.yml` - remove PostgreSQL port exposure:

```yaml
postgres:
  # Remove or comment out:
  # ports:
  #   - "${POSTGRES_PORT:-5432}:5432"
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
echo "strong_password" | docker secret create postgres_password -

# Update docker-compose.yml to use secrets
```

## Backup and Recovery

### Automated Backups

Set up cron job for regular backups:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/Pentaho-Server-PostgreSQL/scripts/backup-postgres.sh

# Add weekly cleanup (keep last 30 days)
0 3 * * 0 find /path/to/Pentaho-Server-PostgreSQL/backups/ -name "*.sql.gz" -mtime +30 -delete
```

### Disaster Recovery

**Complete System Recovery:**

1. Install Docker and Docker Compose on new system
2. Clone/copy this entire project directory
3. Place Pentaho ZIP in `docker/stagedArtifacts/`
4. Restore .env file with original configuration
5. Restore database from backup:
   ```bash
   ./scripts/restore-postgres.sh backups/your-backup.sql.gz
   ```
6. Start services:
   ```bash
   docker compose up -d
   ```

### Volume Backups

Backup Docker volumes:

```bash
# Backup PostgreSQL volume
docker run --rm \
  -v pentaho_postgres_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/postgres-volume-$(date +%Y%m%d).tar.gz -C /data .

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
docker compose logs postgres

# Last 100 lines
docker compose logs --tail=100 pentaho-server
```

### Shell Access

```bash
# Pentaho Server shell
docker compose exec pentaho-server bash

# PostgreSQL shell
docker compose exec postgres bash

# psql directly
docker compose exec postgres psql -U postgres
```

### Resource Monitoring

```bash
# Real-time resource usage
docker stats

# Disk usage
docker system df

# Volume details
docker volume ls
docker volume inspect pentaho_postgres_data
```

## Support and Resources

### Documentation

- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)
- [Docker Documentation](https://docs.docker.com/)
- [PostgreSQL 15 Documentation](https://www.postgresql.org/docs/15/)

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
Pentaho-Server-PostgreSQL/
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
├── db_init_postgres/            # PostgreSQL initialization scripts
│   ├── 1_create_jcr_postgres.sql    # JackRabbit content repository
│   ├── 2_create_quartz_postgres.sql # Quartz scheduler
│   ├── 3_create_repository_postgres.sql # Hibernate repository
│   ├── 4_pentaho_logging_postgres.sql # Audit logging
│   └── 5_pentaho_mart_postgres.sql  # Operations mart
│
├── postgres-config/             # PostgreSQL configuration
│   └── custom.conf              # Performance tuning settings
│
├── softwareOverride/            # Pentaho configuration overrides
│   ├── README.md                # Override system documentation
│   ├── 1_drivers/               # JDBC drivers
│   ├── 2_repository/            # Database configuration
│   ├── 3_security/              # Authentication settings
│   ├── 4_others/                # Tomcat and app configuration
│   └── 99_exchange/             # User data exchange
│
├── scripts/                     # Utility scripts
│   ├── backup-postgres.sh       # Database backup
│   ├── restore-postgres.sh      # Database restore
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
| `docker-compose.yml` | Defines all services (pentaho-server, postgres), networks, and volumes |
| `docker/Dockerfile` | Multi-stage build using `debian:trixie-slim` with OpenJDK 21 |
| `docker/entrypoint/docker-entrypoint.sh` | Processes softwareOverride directories at startup |
| `.env` | Environment-specific configuration (ports, passwords, memory) |
| `deploy.sh` | Automated deployment with pre-flight checks |
| `Makefile` | Convenience commands (run `make help` for list) |
| `db_init_postgres/*.sql` | PostgreSQL database initialization scripts |

## Recent Changes

### Version 1.3.0 (2026-01-16)

**Clean Deployment Flow:**
- On initial deployment, database users are created with the default password "password"
- Vault stores the same default password to ensure Pentaho can connect immediately
- After verifying the deployment works, run `./scripts/rotate-secrets.sh` to secure passwords
- This change fixes connection failures that occurred when Vault generated random passwords on first start

**Password Rotation Policy:**
- Recommended rotation interval: every 90 days
- The validation script now shows:
  - Whether default or rotated passwords are in use
  - Days since last rotation
  - Next recommended rotation date
- Passwords are NEVER rotated automatically - manual rotation ensures you control when restarts occur

**Script Documentation:**
- All scripts now include comprehensive header documentation
- Each script explains its purpose, usage, and deployment flow
- Added ASCII flow diagrams for visual understanding

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
- Docker secrets integration for PostgreSQL password

**Container Hardening:**
- PostgreSQL container now runs in read-only mode
- Added tmpfs mounts for writable directories
- Pentaho server has tmpfs for Tomcat temp and work directories

**Resource Management:**
- Added CPU and memory limits to all containers
- Vault: 512MB RAM, 0.5 CPUs
- PostgreSQL: 2GB RAM, 2 CPUs
- Pentaho: 6GB RAM (configurable), 4 CPUs

**Reliability:**
- Added JSON log driver with rotation to all containers
- Added `stop_grace_period: 60s` for graceful shutdown
- Increased health check retries for Pentaho startup

**New Files:**
- `vault/config/vault.hcl` - Vault server configuration
- `vault/policies/pentaho-policy.hcl` - Access policy
- `secrets/postgres_password.txt` - Docker secrets file
- `scripts/vault-init.sh` - Vault initialization script
- `scripts/fetch-secrets.sh` - Secret retrieval helper

### Version 1.0.0 (2026-01-13)

**Docker Image Changes:**
- Base image: `debian:trixie-slim` with OpenJDK 21 JRE
- No dependency on private container registries

**PostgreSQL Configuration:**
- PostgreSQL 15 with optimized settings
- Three separate databases for Pentaho components
- pg_dump for backup/restore operations

**Accessing Logs:**
Use Docker's native logging:
```bash
# View Pentaho Server logs
docker compose logs -f pentaho-server

# View PostgreSQL logs
docker compose logs -f postgres

# View last 100 lines
docker compose logs --tail=100 pentaho-server
```

---

**Project Version**: 1.3.0
**Pentaho Version**: 11.0.0.0-237
**PostgreSQL Version**: 15
**Last Updated**: 2026-01-16

For questions or issues with this deployment, refer to the Troubleshooting section or review the generated logs.
