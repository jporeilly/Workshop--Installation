# On-Prem Pentaho Server Docker Project

Docker deployment solution for **Pentaho Server 11 Enterprise Edition** with support for multiple database backends.

## Supported Database Configurations

| Database | Folder | Status |
|----------|--------|--------|
| PostgreSQL 15 | `pentaho-server-postgres/` | **Recommended** |
| MySQL | `pentaho-server-mysql/` | Available |
| Oracle | `pentaho-server-oracle/` | Available |
| SQL Server | `pentaho-server-sqlserver/` | Available |

## Quick Start (PostgreSQL)

```bash
# 1. Copy Pentaho distribution to staged artifacts
# Place pentaho-server-ee-11.0.0.0-237.zip in assemblies/pentaho-server/stagedArtifacts/

# 2. Build the Docker image
cd assemblies/pentaho-server
docker build -t pentaho/pentaho-server:11.0.0.0-237 .

# 3. Start Pentaho Server with PostgreSQL
cd dist/on-prem/pentaho-server/pentaho-server-postgres
docker-compose -f docker-compose-postgres.yaml up -d

# 4. Access the server
# URL: http://localhost:8090/pentaho
# Login: admin / password
```

## Project Structure

```text
Pentaho-Docker/
├── assemblies/
│   └── pentaho-server/
│       ├── Dockerfile              # Docker image build file
│       ├── entrypoint/
│       │   ├── docker-entrypoint.sh
│       │   └── docker-entrypoint-init/
│       └── stagedArtifacts/        # Place ZIP files here for offline builds
│
└── dist/on-prem/pentaho-server/
    ├── pentaho-server-postgres/    # PostgreSQL configuration
    │   ├── .env                    # Environment variables
    │   ├── docker-compose-postgres.yaml
    │   ├── config/                 # Pentaho user config (mounted)
    │   ├── db_init_postgres/       # Database init scripts
    │   ├── logs/                   # Tomcat logs (mounted)
    │   └── softwareOverride/       # Configuration overrides
    ├── pentaho-server-mysql/
    ├── pentaho-server-oracle/
    └── pentaho-server-sqlserver/
```

## Prerequisites

- **Docker Engine** 20.10 or later
- **Docker Compose** 2.0 or later
- **Memory**: Minimum 8GB RAM allocated to Docker
- **Pentaho License**: Valid EE license from Hitachi Vantara

## Offline Deployment

For air-gapped environments, download these files from the [Hitachi Vantara Support Portal](https://support.hitachivantara.com):

### Required

- `pentaho-server-ee-11.0.0.0-237.zip` - Main server distribution

### Optional Plugins

- `paz-plugin-ee-11.0.0.0-237.zip` - Pentaho Analyzer
- `pir-plugin-ee-11.0.0.0-237.zip` - Interactive Reports
- `pdd-plugin-ee-11.0.0.0-237.zip` - Dashboard Designer

Place all files in: `assemblies/pentaho-server/stagedArtifacts/`

## Building the Docker Image

```bash
cd assemblies/pentaho-server

# Build with default version
docker build -t pentaho/pentaho-server:11.0.0.0-237 .

# Build with custom version
docker build --build-arg PENTAHO_VERSION=11.0.0.0-237 -t pentaho/pentaho-server:11.0.0.0-237 .
```

## Running with PostgreSQL (Recommended)

```bash
cd dist/on-prem/pentaho-server/pentaho-server-postgres

# Start in detached mode
docker-compose -f docker-compose-postgres.yaml up -d

# View logs
docker-compose -f docker-compose-postgres.yaml logs -f

# Stop services
docker-compose -f docker-compose-postgres.yaml down
```

### PostgreSQL Connection Details

| Parameter | Value |
|-----------|-------|
| Host (external) | localhost |
| Port (external) | 5433 |
| Host (internal) | repository |
| Port (internal) | 5432 |

| Database | Username | Password |
|----------|----------|----------|
| jackrabbit | jcr_user | password |
| quartz | pentaho_user | password |
| hibernate | hibuser | password |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PENTAHO_IMAGE_NAME` | pentaho/pentaho-server | Docker image name |
| `PENTAHO_VERSION` | 11.0.0.0-237 | Pentaho version |
| `PORT` | 8090 | HTTP port |
| `DATABASE_VERSION` | 15 | Database version |
| `DATABASE_PORT` | 5433 | Database external port |
| `POSTGRES_USER` | postgres | PostgreSQL admin username |
| `POSTGRES_PASSWORD` | password | PostgreSQL admin password |
| `JCR_DB_USER` | jcr_user | Jackrabbit DB username |
| `JCR_DB_PASSWORD` | password | Jackrabbit DB password |
| `QUARTZ_DB_USER` | pentaho_user | Quartz DB username |
| `QUARTZ_DB_PASSWORD` | password | Quartz DB password |
| `HIBERNATE_DB_USER` | hibuser | Hibernate DB username |
| `HIBERNATE_DB_PASSWORD` | password | Hibernate DB password |
| `LICENSE_URL` | (configured) | Flexera license URL |
| `SOFTWARE_OVERRIDE_FOLDER` | ./softwareOverride | Config overrides path |
| `LOG_FOLDER` | ./logs | Log files path |
| `CONFIG_FOLDER` | ./config | User config path |

## Software Override System

The `softwareOverride/` folder allows customizing the Pentaho installation. Files are copied in alphabetical order:

| Folder | Purpose |
|--------|---------|
| `1_drivers/` | JDBC drivers |
| `2_repository/` | Repository configs (Jackrabbit, Quartz, Hibernate) |
| `3_security/` | Spring Security configuration |
| `4_others/` | Additional customizations |
| `99_exchange/` | Runtime file exchange |

## Accessing Pentaho Server

| URL | Description |
|-----|-------------|
| http://localhost:8090/pentaho | User Console (PUC) |
| http://localhost:8090/pentaho/api | REST API |
| http://localhost:8090/pentaho/kettle | Carte/PDI Server |

### Default Users

| Username | Password | Role |
|----------|----------|------|
| admin | password | Administrator |
| suzy | password | Power User |
| pat | password | Business Analyst |
| tiffany | password | Report Author |

## Troubleshooting

### Container fails to start

```bash
# Check container status
docker-compose -f docker-compose-postgres.yaml ps

# View detailed logs
docker-compose -f docker-compose-postgres.yaml logs pentaho-server
```

### Database connection issues

1. Wait 30-60 seconds for database initialization on first start
2. Verify PostgreSQL container is healthy: `docker-compose ps`
3. Check JDBC URLs in `softwareOverride/2_repository/tomcat/webapps/pentaho/META-INF/context.xml`

### Memory issues

Adjust JVM settings in `docker-compose-postgres.yaml`:

```yaml
environment:
  JAVA_XMS: "4096m"
  JAVA_XMX: "8192m"
```

### License activation

1. Verify `LICENSE_URL` in `.env` file
2. Ensure network access to Flexera license server
3. Check logs: `docker-compose logs pentaho-server | grep -i license`

## Additional Resources

- **PostgreSQL Setup**: See `pentaho-server-postgres/config/README.md`
- **Offline Deployment**: See `assemblies/pentaho-server/stagedArtifacts/README.md`
- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)
