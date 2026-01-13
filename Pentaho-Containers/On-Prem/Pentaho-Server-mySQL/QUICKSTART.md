# Pentaho Server 11 with MySQL - Quick Start Guide

Get Pentaho Server 11 running with MySQL 8.0 in under 10 minutes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step-by-Step Setup](#step-by-step-setup)
- [Verification](#verification)
- [Common Commands](#common-commands)
- [Useful Shortcuts (Makefile)](#useful-shortcuts-makefile)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)
- [Getting Help](#getting-help)
- [Architecture](#architecture)
- [Data Persistence](#data-persistence)
- [Production Deployment](#production-deployment)

## Prerequisites

- Ubuntu 24.04 LTS
- Docker Engine 20.10+ installed
- Docker Compose 2.0+ installed
- 10GB+ free disk space
- Pentaho Server EE package (ZIP)

## Step-by-Step Setup

### Step 1: Download Pentaho Package

Obtain the Pentaho Server Enterprise Edition package and place it in the correct location:

```bash
cp pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
```

### Step 2: Create Environment File

```bash
cp .env.template .env
```

**Optional:** Edit `.env` to customize settings:
```bash
nano .env
```

Key settings:
- `MYSQL_ROOT_PASSWORD` - MySQL root password
- `PENTAHO_HTTP_PORT` - Web interface port (default: 8090)
- `PENTAHO_MAX_MEMORY` - JVM heap size (default: 4096m)

### Step 3: Run Deployment

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Validate prerequisites
2. Build the Pentaho Server Docker image (~5-10 minutes)
3. Start MySQL and initialize databases
4. Start Pentaho Server (~2-3 minutes)

### Step 4: Access Pentaho

Once deployment completes, access Pentaho at:

**URL:** http://localhost:8090/pentaho

**Credentials:**
- Username: `admin`
- Password: `password`

## Verification

### Check Services Status

```bash
docker compose ps
```

Expected output:
```
NAME                 STATUS
pentaho-server       Up (healthy)
pentaho-mysql        Up (healthy)
```

### View Logs

```bash
# All services
docker compose logs -f

# Pentaho Server only
docker compose logs -f pentaho-server

# MySQL only
docker compose logs -f mysql
```

### Test Database Connection

```bash
docker exec -it pentaho-mysql mysql -uroot -ppassword -e "SHOW DATABASES;"
```

Expected databases:
- `jackrabbit` - JCR content repository
- `quartz` - Scheduler
- `hibernate` - Repository metadata
- `pentaho_logging` - Audit logging
- `pentaho_mart` - Operations analytics

## Common Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose stop

# Restart Pentaho
docker compose restart pentaho-server

# View all logs
docker compose logs -f

# Shutdown everything
docker compose down

# Backup databases
./scripts/backup-mysql.sh

# Restore from backup
./scripts/restore-mysql.sh backups/backup-file.sql.gz
```

## Useful Shortcuts (Makefile)

```bash
# Deploy everything
make deploy

# Start services
make up

# Stop services
make down

# View Pentaho logs
make logs-follow

# Open MySQL shell
make mysql-shell

# Backup databases
make backup

# Show all commands
make help
```

## Troubleshooting

### Container Won't Start

```bash
# Check Docker is running
sudo systemctl status docker

# Check container logs
docker compose logs pentaho-server
```

### Port Already in Use

```bash
# Find what's using port 8090
sudo lsof -i :8090

# Or change the port in .env
PENTAHO_HTTP_PORT=8091
```

### MySQL Connection Error

```bash
# Verify MySQL is running
docker compose ps mysql

# Check MySQL logs
docker compose logs mysql

# Test connection
docker exec pentaho-mysql mysqladmin ping -uroot -ppassword
```

### JDBC Driver Missing

The MySQL Connector/J driver is included in this project. If you need to verify:

```bash
ls -lh softwareOverride/1_drivers/tomcat/lib/mysql-connector-*.jar
```

### Out of Memory

Increase JVM memory in `.env`:
```bash
PENTAHO_MAX_MEMORY=6144m  # 6GB
```

Then restart:
```bash
docker compose restart pentaho-server
```

## Next Steps

### Change Default Passwords

1. **MySQL Root Password** - Edit `.env` and recreate containers
2. **Pentaho Admin** - Change via web interface after first login
3. **Database Users** - Update in SQL scripts and configuration files

### Configure SSL/TLS

See `CONFIGURATION.md` for HTTPS setup instructions.

### Setup Backups

Add cron job for automated backups:
```bash
crontab -e
```

Add line:
```cron
0 2 * * * /home/pentaho/Pentaho-Server-mySQL/scripts/backup-mysql.sh
```

### Review Security

See `README.md` "Production Hardening" section for security checklist.

## Getting Help

- **README.md** - Complete documentation
- **CONFIGURATION.md** - Detailed configuration guide
- **Makefile** - Run `make help` for available commands
- **Pentaho Logs** - `docker compose logs -f pentaho-server`
- **MySQL Logs** - `docker compose logs -f mysql`

## Architecture

```
┌─────────────────────────────────────────┐
│  pentaho-server:8090                    │
│  - Pentaho Server 11.0.0.0-237          │
│  - Tomcat 9                             │
│  - OpenJDK 21                           │
└─────────────┬───────────────────────────┘
              │ JDBC Connection (port 3306)
              ▼
┌─────────────────────────────────────────┐
│  mysql:3306 (hostname: repository)      │
│  - MySQL 8.0                            │
│  - 5 Pentaho Databases:                 │
│    • jackrabbit (JCR)                   │
│    • quartz (Scheduler)                 │
│    • hibernate (Repository)             │
│    • pentaho_logging (Logging)          │
│    • pentaho_mart (Mart)                │
└─────────────────────────────────────────┘
```

## Data Persistence

All data is stored in Docker volumes and persists across container restarts:

- `pentaho_mysql_data` - MySQL databases
- `pentaho_solutions` - Pentaho solutions repository
- `pentaho_data` - Pentaho data files

## Production Deployment

For production use:

1. Change all default passwords
2. Restrict database port exposure
3. Configure firewall rules
4. Setup SSL/TLS certificates
5. Implement automated backups
6. Configure monitoring and alerting

See [README.md](README.md) for complete production hardening guide.

## Related Documentation

- [README.md](README.md) - Complete deployment guide
- [CONFIGURATION.md](CONFIGURATION.md) - Detailed configuration reference
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Project overview and status

---

**Ready to go!** You should now have Pentaho Server 11 running with MySQL. Access it at http://localhost:8090/pentaho
