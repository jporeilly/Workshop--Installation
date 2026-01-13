# Pentaho Server 11 with MySQL - Project Summary

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

This project provides a complete Docker-based deployment of **Pentaho Server 11.0.0.0-237** with **MySQL 8.0** as the repository database on Ubuntu 24.04.

## Project Status

**Status:** COMPLETE - All components have been successfully created and are ready for deployment.

## What's Included

### Core Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Orchestrates Pentaho Server and MySQL |
| `.env.template` | Environment configuration template |
| `deploy.sh` | Automated deployment script |
| `Makefile` | Convenient command shortcuts |
| `.gitignore` | Git exclusions |

### Database Initialization Scripts (`db_init_mysql/`)

| Script | Purpose |
|--------|---------|
| `1_create_jcr_mysql.sql` | Jackrabbit content repository |
| `2_create_quartz_mysql.sql` | Quartz scheduler |
| `3_create_repository_mysql.sql` | Hibernate repository |
| `4_pentaho_logging_mysql.sql` | Audit logging tables |
| `5_pentaho_mart_mysql.sql` | Operations mart |

### Docker Configuration (`docker/`)

| Component | Description |
|-----------|-------------|
| `Dockerfile` | Multi-stage build for Pentaho Server |
| `entrypoint/` | Container startup scripts |
| `stagedArtifacts/` | Directory for Pentaho ZIP package (needs user input) |

### Pentaho Configuration (`softwareOverride/`)

| Directory | Contents |
|-----------|----------|
| `1_drivers/` | JDBC driver (MySQL Connector/J 8.3.0 included) |
| `2_repository/` | Database configuration (context.xml, hibernate-settings.xml, repository.xml) |
| `3_security/` | Authentication settings |
| `4_others/` | Tomcat and application settings |
| `99_exchange/` | User data exchange |

### Utility Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `backup-mysql.sh` | Backup all Pentaho databases |
| `restore-mysql.sh` | Restore databases from backup |
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
| `mysql-config/` | MySQL configuration (custom.cnf) |
| `backups/` | Database backup storage |

## Key Features

### MySQL Integration

- MySQL 8.0 with utf8mb4 character set
- Five separate databases for Pentaho components
- Automatic database initialization on first start
- MySQL Connector/J 8.3.0 driver included

### Docker Architecture

- Multi-container setup with docker-compose
- Health checks and dependency management
- Named volumes for data persistence
- Isolated bridge network
- Service auto-restart policies

### Security

- Non-root user execution (UID 5000)
- Configurable root password
- Separate database users for each component
- Optional port restrictions

### Operations

- Automated backup scripts
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

## Quick Start

1. **Place Pentaho Package**
   ```bash
   cp pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/
   ```

2. **Create Environment File**
   ```bash
   cp .env.template .env
   ```

3. **Deploy**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

4. **Access Pentaho**
   - URL: http://localhost:8090/pentaho
   - Username: `admin`
   - Password: `password`

## Configuration Highlights

### Environment Variables (.env)

```bash
# MySQL
MYSQL_ROOT_PASSWORD=password  # Change for production!
MYSQL_PORT=3306

# Pentaho
PENTAHO_HTTP_PORT=8090
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m
```

### Database Users

| User | Password | Databases |
|------|----------|-----------|
| root | password | All (admin) |
| jcr_user | password | jackrabbit |
| quartz_user | password | quartz |
| hibuser | password | hibernate, pentaho_logging, pentaho_mart |

### JDBC Connection String Format

```
jdbc:mysql://repository:3306/{database}?useSSL=false&allowPublicKeyRetrieval=true
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
             │ JDBC (port 3306)
             ▼
┌─────────────────────────────────┐
│  mysql:3306 (repository)        │
│  - MySQL 8.0                    │
│                                 │
│  Databases:                     │
│  • jackrabbit                   │
│  • quartz                       │
│  • hibernate                    │
│  • pentaho_logging              │
│  • pentaho_mart                 │
└─────────────────────────────────┘
```

## Data Persistence

### Docker Volumes

- `pentaho_mysql_data` - MySQL databases (/var/lib/mysql)
- `pentaho_solutions` - Pentaho solutions repository
- `pentaho_data` - Pentaho data files

### Bind Mounts

- `./config/.kettle` -> `/home/pentaho/.kettle`
- `./config/.pentaho` -> `/home/pentaho/.pentaho`
- `./softwareOverride` -> `/docker-entrypoint-init` (read-only)

## Port Assignments

| Service | Port | Description |
|---------|------|-------------|
| Pentaho HTTP | 8090 | Web interface |
| Pentaho HTTPS | 8443 | Secure web (when configured) |
| MySQL | 3306 | Database connections |

## Security Checklist

| Task | Description |
|------|-------------|
| Change Root Password | Update `MYSQL_ROOT_PASSWORD` in `.env` |
| Update DB Passwords | Update database user passwords in SQL scripts |
| Update context.xml | Update passwords in `context.xml` |
| Change Admin Password | Change Pentaho admin password after first login |
| Restrict DB Port | Comment out MySQL port in docker-compose.yml |
| Configure Firewall | Setup firewall rules |
| Setup SSL/TLS | Configure SSL/TLS for Pentaho |
| Automated Backups | Implement automated backups |
| Monitoring | Setup monitoring and alerting |

## Production Considerations

### Resource Recommendations

- **Minimum**: 4 CPU cores, 8GB RAM, 20GB disk
- **Recommended**: 8+ CPU cores, 16GB+ RAM, 50GB+ disk
- **Production**: 16+ CPU cores, 32GB+ RAM, 100GB+ SSD

### Performance Tuning

- Adjust `innodb_buffer_pool_size` in `mysql-config/custom.cnf`
- Tune JVM heap sizes in `.env`
- Configure MySQL slow query logging
- Monitor query performance

## Troubleshooting

### Common Issues

**Container fails to start**
- Check logs: `docker compose logs mysql`
- Verify disk space
- Check port conflicts

**Connection refused**
- Verify MySQL is healthy: `docker compose ps`
- Check network: `docker network ls`

See `README.md` and `QUICKSTART.md` for detailed troubleshooting.

## Related Documentation

- [README.md](README.md) - Complete deployment guide
- [QUICKSTART.md](QUICKSTART.md) - Fast setup instructions
- [CONFIGURATION.md](CONFIGURATION.md) - Configuration reference
- `scripts/*.sh` - Utility scripts
- `Makefile` - Run `make help` for commands

## License & Trademarks

- Pentaho is a registered trademark of Hitachi Vantara Corporation
- MySQL is a trademark of Oracle Corporation
- This deployment configuration provided as-is
- Pentaho Server requires appropriate licensing for enterprise use

## Version Information

- **Project Version**: 1.0.0
- **Pentaho Version**: 11.0.0.0-237
- **MySQL Version**: 8.0
- **Base Image**: debian:trixie-slim
- **Java Version**: OpenJDK 21 JRE
- **Creation Date**: 2026-01-12

## Next Steps

1. Download Pentaho Server package
2. Run deployment: `./deploy.sh`
3. Access Pentaho at http://localhost:8090/pentaho
4. Change default passwords
5. Configure backups
6. Review security settings

---

**Status:** Ready for deployment
**Created:** January 12, 2026
**Platform:** Ubuntu 24.04 LTS with Docker
