# Pentaho Server 11 with Oracle - Quick Start Guide

Get Pentaho Server 11 running with Oracle Database 23c Free in under 15 minutes.

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
- 15GB+ free disk space (Oracle needs ~8GB)
- Pentaho Server EE package (ZIP)
- Oracle JDBC Driver (ojdbc11.jar)

## Step-by-Step Setup

### Step 1: Download Pentaho Package

Obtain the Pentaho Server Enterprise Edition package and place it in the correct location:

```bash
cp pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
```

### Step 2: Download Oracle JDBC Driver

Download from Oracle and place in drivers directory:

```bash
# Download ojdbc11.jar from Oracle website
# https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html

cp ojdbc11.jar softwareOverride/1_drivers/tomcat/lib/
```

Verify the driver is in place:
```bash
ls -lh softwareOverride/1_drivers/tomcat/lib/ojdbc*.jar
```

### Step 3: Create Environment File

```bash
cp .env.template .env
```

**Optional:** Edit `.env` to customize settings:
```bash
nano .env
```

Key settings:
- `ORACLE_PASSWORD` - Oracle database password
- `PENTAHO_HTTP_PORT` - Web interface port (default: 8090)
- `PENTAHO_MAX_MEMORY` - JVM heap size (default: 4096m)

### Step 4: Run Deployment

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
1. Validate prerequisites
2. Build the Pentaho Server Docker image (~5-10 minutes)
3. Start Oracle Database and initialize schemas (~2-5 minutes first run)
4. Start Pentaho Server (~2-3 minutes)

### Step 5: Access Pentaho

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
pentaho-oracle       Up (healthy)
```

### View Logs

```bash
# All services
docker compose logs -f

# Pentaho Server only
docker compose logs -f pentaho-server

# Oracle only
docker compose logs -f oracle
```

### Test Database Connection

```bash
docker exec -it pentaho-oracle sqlplus -s hibuser/password@//localhost:1521/FREEPDB1 <<< "SELECT 1 FROM DUAL;"
```

Expected schemas:
- `jcr_user` - JCR content repository
- `pentaho_user` - Scheduler
- `hibuser` - Repository metadata, logging, operations mart

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
./scripts/backup-oracle.sh

# Restore from backup
./scripts/restore-oracle.sh backups/pentaho_backup_YYYYMMDD.dmp
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

# Open SQL*Plus shell
make oracle-shell

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
docker compose logs oracle
```

### Port Already in Use

```bash
# Find what's using port 8090
sudo lsof -i :8090

# Or change the port in .env
PENTAHO_HTTP_PORT=8091
```

### Oracle Not Starting

```bash
# Check Oracle logs
docker compose logs oracle

# Ensure sufficient disk space (Oracle needs ~8GB)
df -h

# Oracle initialization on first startup takes 2-5 minutes
```

### JDBC Driver Missing

```bash
# Verify driver exists
ls -lh softwareOverride/1_drivers/tomcat/lib/ojdbc*.jar

# If missing, download from Oracle website
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

1. **Oracle Password** - Edit `.env` and recreate containers
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
0 2 * * * /home/pentaho/Pentaho-Server-Oracle/scripts/backup-oracle.sh
```

### Review Security

See `README.md` "Production Hardening" section for security checklist.

## Getting Help

- **README.md** - Complete documentation
- **CONFIGURATION.md** - Detailed configuration guide
- **Makefile** - Run `make help` for available commands
- **Pentaho Logs** - `docker compose logs -f pentaho-server`
- **Oracle Logs** - `docker compose logs -f oracle`

## Architecture

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

## Data Persistence

All data is stored in Docker volumes and persists across container restarts:

- `pentaho_oracle_data` - Oracle database files
- `pentaho_solutions` - Pentaho solutions repository
- `pentaho_data` - Pentaho data files

## Production Deployment

For production use:

1. Change all default passwords
2. Consider Oracle Enterprise Edition (Free has 12GB data limit)
3. Restrict database port exposure
4. Configure firewall rules
5. Setup SSL/TLS certificates
6. Implement automated backups
7. Configure monitoring and alerting

See [README.md](README.md) for complete production hardening guide.

## Related Documentation

- [README.md](README.md) - Complete deployment guide
- [CONFIGURATION.md](CONFIGURATION.md) - Detailed configuration reference
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Project overview and status

---

**Ready to go!** You should now have Pentaho Server 11 running with Oracle. Access it at http://localhost:8090/pentaho
