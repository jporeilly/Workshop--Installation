# Pentaho Server 11 with Oracle - Project Summary

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
- [Related Documentation](#related-documentation)

## Overview

This project provides a complete Docker-based deployment of **Pentaho Server 11.0.0.0-237** with **Oracle Database 23c Free** as the repository database on Ubuntu 24.04.

## Project Status

**Status:** COMPLETE - All components have been successfully created and are ready for deployment.

## What's Included

### Core Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Orchestrates Pentaho Server and Oracle Database |
| `.env.template` | Environment configuration template |
| `deploy.sh` | Automated deployment script |
| `Makefile` | Convenient command shortcuts |
| `.gitignore` | Git exclusions |

### Database Initialization Scripts (`db_init_oracle/`)

| Script | Purpose |
|--------|---------|
| `01_create_users.sql` | Create database users/schemas |
| `02_create_jcr_oracle.sql` | Jackrabbit content repository |
| `03_create_quartz_oracle.sql` | Quartz scheduler |
| `04_create_repository_oracle.sql` | Hibernate repository |

### Docker Configuration (`docker/`)

| Component | Description |
|-----------|-------------|
| `Dockerfile` | Multi-stage build for Pentaho Server |
| `entrypoint/` | Container startup scripts |
| `stagedArtifacts/` | Directory for Pentaho ZIP package (needs user input) |

### Pentaho Configuration (`softwareOverride/`)

| Directory | Contents |
|-----------|----------|
| `1_drivers/` | JDBC driver location (ojdbc11.jar required) |
| `2_repository/` | Database configuration (context.xml, hibernate-settings.xml, repository.xml) |
| `3_security/` | Authentication settings |
| `4_others/` | Tomcat and application settings |
| `99_exchange/` | User data exchange |

### Utility Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `backup-oracle.sh` | Backup databases using Data Pump |
| `restore-oracle.sh` | Restore databases from backup |
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
| `oracle-config/` | Oracle configuration |
| `backups/` | Database backup storage (.dmp files) |

## Key Features

### Oracle Integration

- Oracle Database 23c Free edition
- Three separate schemas for Pentaho components
- Automatic schema initialization on first start
- Oracle Data Pump for backup/restore

### Docker Architecture

- Multi-container setup with docker-compose
- Health checks and dependency management
- Named volumes for data persistence
- Isolated bridge network
- Service auto-restart policies

### Security

- Non-root user execution (UID 5000)
- Configurable Oracle password
- Separate database users for each component
- Optional port restrictions

### Operations

- Automated backup scripts using Data Pump
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

### 2. Oracle JDBC Driver (REQUIRED)

```
softwareOverride/1_drivers/tomcat/lib/ojdbc11.jar
```

Download from: https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html

## Quick Start

1. **Place Pentaho Package**
   ```bash
   cp pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
   ```

2. **Download Oracle JDBC Driver**
   ```bash
   cp ojdbc11.jar softwareOverride/1_drivers/tomcat/lib/
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
# Oracle
ORACLE_PASSWORD=password  # Change for production!
ORACLE_PORT=1521

# Pentaho
PENTAHO_HTTP_PORT=8090
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m
```

### Database Users (Schemas)

| User | Password | Purpose |
|------|----------|---------|
| jcr_user | password | Jackrabbit content repository |
| pentaho_user | password | Quartz scheduler |
| hibuser | password | Hibernate, logging, operations mart |

### JDBC Connection String Format

```
jdbc:oracle:thin:@//repository:1521/FREEPDB1
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
             │ JDBC (port 1521)
             │ Service: FREEPDB1
             ▼
┌─────────────────────────────────┐
│  oracle:1521 (repository)       │
│  - Oracle Database 23c Free     │
│                                 │
│  Schemas:                       │
│  • jcr_user                     │
│  • pentaho_user                 │
│  • hibuser                      │
└─────────────────────────────────┘
```

## Data Persistence

### Docker Volumes

- `pentaho_oracle_data` - Oracle database files
- `pentaho_solutions` - Pentaho solutions repository
- `pentaho_data` - Pentaho data files

### Bind Mounts

- `./config/.kettle` -> `/home/pentaho/.kettle`
- `./config/.pentaho` -> `/home/pentaho/.pentaho`
- `./softwareOverride` -> `/docker-entrypoint-init` (read-only)

## Oracle Free Edition Limitations

| Limitation | Value |
|------------|-------|
| User Data Limit | 12GB |
| RAM Limit | 2GB |
| CPU Threads | 2 |

For production workloads, consider Oracle Standard or Enterprise Edition.

## Port Assignments

| Service | Port | Description |
|---------|------|-------------|
| Pentaho HTTP | 8090 | Web interface |
| Pentaho HTTPS | 8443 | Secure web (when configured) |
| Oracle | 1521 | Database connections |

## Security Checklist

| Task | Description |
|------|-------------|
| Change Oracle Password | Update `ORACLE_PASSWORD` in `.env` |
| Update DB Passwords | Update database user passwords in SQL scripts |
| Update context.xml | Update passwords in `context.xml` |
| Change Admin Password | Change Pentaho admin password after first login |
| Restrict DB Port | Comment out Oracle port in docker-compose.yml |
| Configure Firewall | Setup firewall rules |
| Setup SSL/TLS | Configure SSL/TLS for Pentaho |
| Automated Backups | Implement automated backups |
| Monitoring | Setup monitoring and alerting |

## Production Considerations

### Oracle Edition

- **Free**: 12GB data limit, 2GB RAM, 2 CPU threads
- **Standard**: Licensed, moderate features
- **Enterprise**: Licensed, full features, HA capabilities

### Resource Recommendations

- **Minimum**: 4 CPU cores, 8GB RAM, 20GB disk
- **Recommended**: 8+ CPU cores, 16GB+ RAM, 50GB+ disk
- **Production**: 16+ CPU cores, 32GB+ RAM, 100GB+ SSD

## Troubleshooting

### Common Issues

**Oracle not starting**
- Check logs: `docker compose logs oracle`
- Ensure 8GB+ disk space
- First startup takes 2-5 minutes

**JDBC driver not found**
- Verify ojdbc11.jar in softwareOverride/1_drivers/tomcat/lib/

**Container fails to start**
- Check logs: `docker compose logs pentaho-server`
- Verify disk space

See `README.md` and `QUICKSTART.md` for detailed troubleshooting.

## Related Documentation

- [README.md](README.md) - Complete deployment guide
- [QUICKSTART.md](QUICKSTART.md) - Fast setup instructions
- [CONFIGURATION.md](CONFIGURATION.md) - Configuration reference
- `scripts/*.sh` - Utility scripts
- `Makefile` - Run `make help` for commands

## License & Trademarks

- Pentaho is a registered trademark of Hitachi Vantara Corporation
- Oracle is a trademark of Oracle Corporation
- This deployment configuration provided as-is
- Pentaho Server requires appropriate licensing for enterprise use
- Oracle Standard/Enterprise editions require Oracle licensing

## Version Information

- **Project Version**: 1.0.0
- **Pentaho Version**: 11.0.0.0-237
- **Oracle Version**: 23c Free
- **Base Image**: debian:trixie-slim
- **Java Version**: OpenJDK 21 JRE
- **Creation Date**: 2026-01-13

## Next Steps

1. Download Pentaho Server package
2. Download Oracle JDBC Driver
3. Run deployment: `./deploy.sh`
4. Access Pentaho at http://localhost:8090/pentaho
5. Change default passwords
6. Configure backups
7. Review security settings

---

**Status:** Ready for deployment
**Created:** January 13, 2026
**Platform:** Ubuntu 24.04 LTS with Docker
