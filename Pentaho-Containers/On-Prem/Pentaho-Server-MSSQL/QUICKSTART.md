# Pentaho Server 11 with SQL Server - Quick Start Guide

Get Pentaho Server 11 running with Microsoft SQL Server in under 10 minutes.

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
- Internet connection (for downloading JDBC driver)

## Step-by-Step Setup

### Step 1: Download Pentaho Package

Obtain the Pentaho Server Enterprise Edition package and place it in the correct location:

```bash
cp pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
```

### Step 2: Download SQL Server JDBC Driver

```bash
cd softwareOverride/1_drivers/tomcat/lib/
wget https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar
cd ../../../..
```

Verify the driver is in place:
```bash
ls -lh softwareOverride/1_drivers/tomcat/lib/mssql-jdbc-*.jar
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
- `MSSQL_SA_PASSWORD` - SQL Server SA password (must be complex!)
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
3. Start SQL Server and initialize databases
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
pentaho-mssql        Up (healthy)
pentaho-mssql-init   Exited (0)
```

### View Logs

```bash
# All services
docker compose logs -f

# Pentaho Server only
docker compose logs -f pentaho-server

# SQL Server only
docker compose logs -f mssql
```

### Test Database Connection

```bash
docker exec -it pentaho-mssql /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U SA -P 'YourStr0ng!Passw0rd' \
  -C -Q "SELECT name FROM sys.databases"
```

Expected databases:
- `jackrabbit` - JCR content repository
- `quartz` - Scheduler
- `hibernate` - Repository metadata
- `pentaho_dilogs` - ETL logging
- `pentaho_operations_mart` - Operations analytics

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
./scripts/backup-mssql.sh

# Restore from backup
./scripts/restore-mssql.sh backups/backup-file.tar.gz
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

# Open SQL Server shell
make mssql-shell

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

### SQL Server Password Error

If you see "Password validation failed", ensure your password meets requirements:
- At least 8 characters
- Contains uppercase, lowercase, numbers, and symbols

Example valid password: `YourStr0ng!Passw0rd`

### JDBC Driver Missing

```bash
# Verify driver exists
ls -lh softwareOverride/1_drivers/tomcat/lib/mssql-jdbc-*.jar

# If missing, download it
cd softwareOverride/1_drivers/tomcat/lib/
wget https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar
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

1. **SQL Server SA Password** - Edit `.env` and rebuild
2. **Pentaho Admin** - Change via web interface after first login
3. **Database Users** - Update in SQL Server and configuration files

### Configure SSL/TLS

See `CONFIGURATION.md` for HTTPS setup instructions.

### Setup Backups

Add cron job for automated backups:
```bash
crontab -e
```

Add line:
```cron
0 2 * * * /home/pentaho/Pentaho-Server-MSSQL/scripts/backup-mssql.sh
```

### Review Security

See `README.md` "Production Hardening" section for security checklist.

## Getting Help

- **README.md** - Complete documentation
- **CONFIGURATION.md** - Detailed configuration guide
- **Makefile** - Run `make help` for available commands
- **Pentaho Logs** - `docker compose logs -f pentaho-server`
- **SQL Server Logs** - `docker compose logs -f mssql`

## Architecture

```
┌─────────────────────────────────────────┐
│  pentaho-server:8090                    │
│  - Pentaho Server 11.0.0.0-237          │
│  - Tomcat 9                             │
│  - OpenJDK 21                           │
└─────────────┬───────────────────────────┘
              │ JDBC Connection (port 1433)
              │ encrypt=false;trustServerCertificate=true
              ▼
┌─────────────────────────────────────────┐
│  mssql:1433 (hostname: repository)      │
│  - Microsoft SQL Server 2022            │
│  - 5 Pentaho Databases:                 │
│    • jackrabbit (JCR)                   │
│    • quartz (Scheduler)                 │
│    • hibernate (Repository)             │
│    • pentaho_dilogs (Logging)           │
│    • pentaho_operations_mart (Mart)     │
└─────────────────────────────────────────┘
```

## Data Persistence

All data is stored in Docker volumes and persists across container restarts:

- `pentaho_mssql_data` - SQL Server databases
- `pentaho_solutions` - Pentaho solutions repository
- `pentaho_data` - Pentaho data files

## Production Deployment

For production use:

1. Change all default passwords
2. Use Standard or Enterprise edition (`MSSQL_PID=Standard`)
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

**Ready to go!** You should now have Pentaho Server 11 running with SQL Server. Access it at http://localhost:8090/pentaho
