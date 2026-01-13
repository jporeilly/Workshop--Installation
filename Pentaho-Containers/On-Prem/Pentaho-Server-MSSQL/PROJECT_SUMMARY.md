# Pentaho Server 11 with Microsoft SQL Server - Project Summary

## Table of Contents

- [Overview](#overview)
- [Project Status](#project-status)
- [What's Included](#whats-included)
- [Key Features](#key-features)
- [What You Need to Provide](#what-you-need-to-provide)
- [Quick Start](#quick-start)
- [Configuration Highlights](#configuration-highlights)
- [Architecture](#architecture)
- [Data Persistence](#data-persistence)
- [Differences from MySQL/PostgreSQL/Oracle Projects](#differences-from-mysqlpostgresqloracle-projects)
- [Related Documentation](#related-documentation)

## Overview

This project provides a complete Docker-based deployment of **Pentaho Server 11.0.0.0-237** with **Microsoft SQL Server 2022** as the repository database on Ubuntu 24.04.

## Project Status

**Status:** COMPLETE - All components have been successfully created and are ready for deployment.

## What's Included

### Core Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Orchestrates Pentaho Server, SQL Server, and initialization |
| `.env.template` | Environment configuration template |
| `deploy.sh` | Automated deployment script |
| `Makefile` | Convenient command shortcuts |
| `.gitignore` | Git exclusions |

### Database Initialization Scripts (`db_init_mssql/`)

| Script | Purpose |
|--------|---------|
| `01_create_jcr_mssql.sql` | Jackrabbit content repository |
| `02_create_quartz_mssql.sql` | Quartz scheduler |
| `03_create_repository_mssql.sql` | Hibernate repository |
| `04_pentaho_dilogs_mssql.sql` | ETL logging tables |
| `05_pentaho_operations_mart_mssql.sql` | Operations mart (22 tables) |

### Docker Configuration (`docker/`)

| Component | Description |
|-----------|-------------|
| `Dockerfile` | Multi-stage build for Pentaho Server |
| `entrypoint/` | Container startup scripts |
| `stagedArtifacts/` | Directory for Pentaho ZIP package (needs user input) |

### Pentaho Configuration (`softwareOverride/`)

| Directory | Contents |
|-----------|----------|
| `1_drivers/` | JDBC driver location with download instructions |
| `2_repository/` | Database configuration (context.xml, hibernate-settings.xml, repository.xml, audit_sql.xml, repository.spring.properties, scheduler-plugin/) |
| `3_security/` | Authentication settings |
| `4_others/` | Tomcat and application settings |
| `99_exchange/` | User data exchange |

### Utility Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `backup-mssql.sh` | Backup all Pentaho databases to .bak files |
| `restore-mssql.sh` | Restore databases from backup |
| `validate-deployment.sh` | Verify deployment health |

### Documentation

| Document | Description |
|----------|-------------|
| `README.md` | Comprehensive deployment guide |
| `QUICKSTART.md` | Quick start guide |
| `CONFIGURATION.md` | Detailed configuration reference |
| `PROJECT_SUMMARY.md` | This file |

### Configuration Directories

| Directory | Purpose |
|-----------|---------|
| `config/.kettle/` | PDI configuration |
| `config/.pentaho/` | Pentaho user settings |
| `mssql-config/` | SQL Server configuration (mssql.conf) |
| `backups/` | Database backup storage |
| `logs/` | Application logs |

## Key Features

### SQL Server Integration

- Microsoft SQL Server 2022 (Developer Edition)
- Five separate databases for Pentaho components
- Automated initialization via mssql-init container
- Proper schema configuration for all Jackrabbit components

### Docker Architecture

- Multi-container setup with docker-compose
- Health checks and dependency management
- Named volumes for data persistence
- Isolated bridge network
- Service auto-restart policies

### Security

- Non-root user execution (UID 5000)
- Configurable SA password with complexity enforcement
- Separate database users for each component
- Optional port restrictions
- Encryption options (can be enabled)

### Operations

- Automated backup scripts using SQL Server native backup
- Database restore functionality
- Deployment validation script
- Comprehensive logging
- Makefile for common operations

## What You Need to Provide

### 1. Pentaho Server Package (REQUIRED)
```
docker/stagedArtifacts/pentaho-server-ee-11.0.0.0-237.zip
```
Obtain from Hitachi Vantara

### 2. Microsoft JDBC Driver (REQUIRED)
```
softwareOverride/1_drivers/tomcat/lib/mssql-jdbc-12.8.1.jre11.jar
```

Download command:
```bash
cd softwareOverride/1_drivers/tomcat/lib/
wget https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar
```

## Quick Start

1. **Place Pentaho Package**
   ```bash
   cp pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
   ```

2. **Download JDBC Driver**
   ```bash
   cd softwareOverride/1_drivers/tomcat/lib/
   wget https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar
   cd ../../..
   ```

3. **Create Environment File**
   ```bash
   cp .env.template .env
   ```

4. **Deploy**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

5. **Access Pentaho**
   - URL: http://localhost:8090/pentaho
   - Username: `admin`
   - Password: `password`

## Configuration Highlights

### Environment Variables (.env)

```bash
# SQL Server
MSSQL_SA_PASSWORD=YourStr0ng!Passw0rd  # Must be complex!
MSSQL_PID=Developer                     # Or Express, Standard, Enterprise
MSSQL_PORT=1433

# Pentaho
PENTAHO_HTTP_PORT=8090
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m
```

### Database Users

| User | Password | Databases |
|------|----------|-----------|
| SA | YourStr0ng!Passw0rd | All (admin) |
| jcr_user | password | jackrabbit |
| pentaho_user | password | quartz |
| hibuser | password | hibernate, pentaho_dilogs, pentaho_operations_mart |

### JDBC Connection String Format

```
jdbc:sqlserver://repository:1433;databaseName={database};encrypt=false;trustServerCertificate=true
```

## Architecture

```
┌─────────────────────────────────┐
│  pentaho-server:8090            │
│  - Pentaho 11.0.0.0-237         │
│  - Debian Trixie                │
│  - OpenJDK 21 JRE               │
│  - Tomcat 9                     │
└────────────┬────────────────────┘
             │ JDBC (port 1433)
             ▼
┌─────────────────────────────────┐
│  mssql:1433 (repository)        │
│  - SQL Server 2022              │
│  - Developer Edition            │
│                                 │
│  Databases:                     │
│  • jackrabbit                   │
│  • quartz                       │
│  • hibernate                    │
│  • pentaho_dilogs               │
│  • pentaho_operations_mart      │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  mssql-init (runs once)         │
│  - Initializes databases        │
│  - Creates users                │
│  - Creates schemas              │
└─────────────────────────────────┘
```

## Data Persistence

### Docker Volumes
- `pentaho_mssql_data` - SQL Server databases (/var/opt/mssql)
- `pentaho_solutions` - Pentaho solutions repository
- `pentaho_data` - Pentaho data files

### Bind Mounts
- `./config/.kettle` → `/home/pentaho/.kettle`
- `./config/.pentaho` → `/home/pentaho/.pentaho`
- `./softwareOverride` → `/docker-entrypoint-init` (read-only)

## Differences from MySQL/PostgreSQL/Oracle Projects

### SQL Server Specific Features
1. **Two-Container Initialization**
   - Main `mssql` container for SQL Server
   - Separate `mssql-init` container for database setup

2. **Password Complexity**
   - Enforced by SQL Server
   - Must contain uppercase, lowercase, numbers, symbols

3. **JDBC Driver**
   - Microsoft JDBC Driver (not included in Pentaho)
   - Must be downloaded separately

4. **Schema Types**
   - Uses `mssql` schema in Jackrabbit
   - Uses `MSSqlPersistenceManager` class

5. **Backup Format**
   - Uses SQL Server native `.bak` files
   - Compressed into `.tar.gz` archives

6. **SQL Server Editions**
   - Configurable via `MSSQL_PID` environment variable
   - Default: Developer (free, not for production)

## Port Assignments

| Service | Port | Description |
|---------|------|-------------|
| Pentaho HTTP | 8090 | Web interface |
| Pentaho HTTPS | 8443 | Secure web (when configured) |
| SQL Server | 1433 | Database connections |

## Security Checklist

| Task | Description |
|------|-------------|
| Change SA Password | Update `MSSQL_SA_PASSWORD` in `.env` |
| Update DB Passwords | Update database user passwords in SQL scripts |
| Update context.xml | Update passwords in `context.xml` |
| Change Admin Password | Change Pentaho admin password after first login |
| Restrict DB Port | Comment out SQL Server port in docker-compose.yml |
| Configure Firewall | Setup firewall rules |
| Setup SSL/TLS | Configure SSL/TLS for Pentaho |
| Production Edition | Use Standard/Enterprise edition for production |
| Automated Backups | Implement automated backups |
| Monitoring | Setup monitoring and alerting |

## Production Considerations

### SQL Server Edition
- **Developer**: Free, full features, NOT for production
- **Express**: Free, limited (10GB), suitable for small deployments
- **Standard**: Licensed, up to 24 cores/128GB RAM
- **Enterprise**: Licensed, unlimited, advanced features

### Resource Recommendations
- **Minimum**: 4 CPU cores, 8GB RAM, 20GB disk
- **Recommended**: 8+ CPU cores, 16GB+ RAM, 50GB+ disk
- **Production**: 16+ CPU cores, 32GB+ RAM, 100GB+ SSD

### Performance Tuning
- Adjust `memorylimitmb` in `mssql-config/mssql.conf`
- Tune JVM heap sizes in `.env`
- Configure SQL Server indexes and statistics
- Monitor query performance

## Known Limitations

1. SQL Server JDBC driver must be downloaded manually (licensing)
2. Developer edition not licensed for production use
3. Express edition has 10GB database size limit
4. Standard/Enterprise editions require SQL Server licensing

## Troubleshooting

### Common Issues

**Password complexity error**
- Ensure SA password has uppercase, lowercase, numbers, symbols

**JDBC driver not found**
- Verify mssql-jdbc-*.jar in softwareOverride/1_drivers/tomcat/lib/

**Container fails to start**
- Check logs: `docker compose logs mssql`
- Verify password meets requirements
- Check disk space

**Connection refused**
- Verify SQL Server is healthy: `docker compose ps`
- Check network: `docker network ls`

See `README.md` and `QUICKSTART.md` for detailed troubleshooting.

## Related Documentation

- [README.md](README.md) - Complete deployment guide
- [QUICKSTART.md](QUICKSTART.md) - Fast setup instructions
- [CONFIGURATION.md](CONFIGURATION.md) - Configuration reference
- `scripts/*.sh` - Utility scripts
- `Makefile` - Run `make help` for commands

## Related Projects

This project follows the same structure as:

- Pentaho-Server-mySQL
- Pentaho-Server-PostgreSQL
- Pentaho-Server-Oracle

All share the same Docker build strategy and configuration patterns.

## License & Trademarks

- Pentaho is a registered trademark of Hitachi Vantara Corporation
- Microsoft SQL Server is a trademark of Microsoft Corporation
- This deployment configuration provided as-is
- Pentaho Server requires appropriate licensing for enterprise use
- SQL Server Standard/Enterprise editions require Microsoft licensing

## Version Information

- **Project Version**: 1.0.0
- **Pentaho Version**: 11.0.0.0-237
- **SQL Server Version**: 2022 (Developer Edition)
- **Base Image**: debian:trixie-slim
- **Java Version**: OpenJDK 21 JRE
- **Creation Date**: 2026-01-13

## Next Steps

1. Download Pentaho Server package
2. Download Microsoft JDBC Driver
3. Run deployment: `./deploy.sh`
4. Access Pentaho at http://localhost:8090/pentaho
5. Change default passwords
6. Configure backups
7. Review security settings

---

**Status:** Ready for deployment
**Created:** January 13, 2026
**Platform:** Ubuntu 24.04 LTS with Docker
