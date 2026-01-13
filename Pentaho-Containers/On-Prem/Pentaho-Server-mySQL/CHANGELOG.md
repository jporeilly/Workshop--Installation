# Changelog

All notable changes to the Pentaho Server 11 Docker Deployment project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-01-12

### Added

- **WORKSHOP.md**: Comprehensive hands-on deployment workshop (~650 lines)
  - Step-by-step deployment instructions
  - Architecture deep-dive with ASCII diagrams
  - Configuration reference
  - Troubleshooting guide
  - Four hands-on exercises

### Fixed

- **Container Health Check**: Added `curl` to Dockerfile and fixed health check endpoint
  - **Issue**: Container showed "unhealthy" because `curl` was not installed in `debian:trixie-slim`
  - **Fix 1**: Added `curl` to apt-get install in Dockerfile pack stage
  - **Fix 2**: Changed health check endpoint from `/pentaho/api/system/version` (requires auth, returns 401) to `/pentaho/Login` (public, returns 200)
  - Container now properly reports "healthy" status

---

## [1.0.0] - 2026-01-12

### Added

- **MySQL JDBC Driver**: Added `mysql-connector-j-8.3.0.jar` to `softwareOverride/1_drivers/tomcat/lib/`
  - Required for Pentaho Server to connect to MySQL repository
  - Version 8.3.0 is compatible with MySQL 8.0
  - Driver is automatically included in container during build

- **Comprehensive Documentation**:
  - Expanded README.md with Software Override System section
  - Created this CHANGELOG.md for version tracking
  - Created ARCHITECTURE.md for system design documentation
  - Created CONFIGURATION.md for configuration reference
  - Created TROUBLESHOOTING.md for extended problem-solving guide
  - Expanded softwareOverride/README.md from 2 lines to comprehensive guide

- **Deployment Automation**:
  - `deploy.sh` script with pre-flight checks
  - `Makefile` with 35+ convenience targets
  - `validate-deployment.sh` for deployment verification
  - Backup and restore scripts for MySQL databases

### Changed

- **Docker Base Image**: Changed from Hitachi Vantara registry to `debian:trixie-slim`
  - **Before**: `one.hitachivantara.com/docker/debian:trixie-slim` (private registry)
  - **After**: `debian:trixie-slim` (public Docker Hub)
  - Removes dependency on private container registry
  - Uses official Debian packages for better compatibility
  - Includes OpenJDK 21 JRE from Debian repositories

- **Entrypoint Script Location**: Moved to `docker/entrypoint/` subdirectory
  - **Before**: `docker/docker-entrypoint.sh`
  - **After**: `docker/entrypoint/docker-entrypoint.sh`
  - Required for proper Docker COPY directive in Dockerfile
  - Entrypoint directory structure matches Docker conventions

- **Logs Volume**: Commented out bind mount in `docker-compose.yml`
  - **Before**: `./logs:/opt/pentaho/pentaho-server/tomcat/logs`
  - **After**: Volume mount commented out
  - Prevents permission denied errors (container runs as UID 5000)
  - Use `docker compose logs` to access container logs instead

### Fixed

- **Permission Denied Errors**: Resolved log file permission issues
  - Container runs as non-root user `pentaho` (UID 5000)
  - Host-mounted log directories caused permission conflicts
  - Solution: Use Docker's native logging instead of bind mounts

- **MySQL Driver Class Not Found**: Resolved database connection failures
  - Pentaho requires MySQL Connector/J for repository connections
  - Driver was missing from base installation
  - Solution: Added driver to softwareOverride/1_drivers/tomcat/lib/

- **Container Startup Failures**: Resolved entrypoint execution errors
  - Entrypoint script location was incorrect for Docker COPY
  - Script lacked execute permissions after copy
  - Solution: Moved to entrypoint/ directory, ensured execute permissions

### Removed

- **Hitachi Vantara Registry Dependency**: No longer requires private registry access
  - Simplifies deployment in air-gapped or restricted environments
  - All base images now from public Docker Hub

## [0.9.0] - 2026-01-05

### Added

- Initial project structure
- Docker Compose configuration for MySQL and Pentaho Server
- Multi-stage Dockerfile for Pentaho Server
- MySQL initialization scripts for 5 Pentaho databases
- Software override mechanism for configuration customization
- Environment variable configuration via .env file

---

## Migration Notes

### Upgrading from 0.9.0 to 1.0.0

1. **Pull latest changes**:
   ```bash
   git pull origin main
   ```

2. **Rebuild container** (required for base image change):
   ```bash
   docker compose build --no-cache pentaho-server
   ```

3. **Restart services**:
   ```bash
   docker compose up -d
   ```

4. **Note on logs**: If you were using the logs volume mount, access logs via:
   ```bash
   docker compose logs -f pentaho-server
   ```

### Breaking Changes

- None in this release. Existing deployments will continue to work after rebuild.

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.1 | 2026-01-12 | Fixed health check, added workshop document |
| 1.0.0 | 2026-01-12 | Production-ready release with documentation |
| 0.9.0 | 2026-01-05 | Initial development release |
