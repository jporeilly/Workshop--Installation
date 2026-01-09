# Pentaho Server 11 with PostgreSQL 15

Complete guide for deploying Pentaho Server 11 Enterprise Edition with PostgreSQL 15 as the repository database using Docker.

## Quick Start

```bash
# 1. Build the Docker image (from project root)
cd assemblies/pentaho-server
docker build -t pentaho/pentaho-server:11.0.0.0-237 .

# 2. Start the containers
cd ../../dist/on-prem/pentaho-server/pentaho-server-postgres
docker-compose -f docker-compose-postgres.yaml up -d

# 3. Access Pentaho Server
# Open browser: http://localhost:8090/pentaho
# Login: admin / password
```

## Deployment Overview

| Component | Version | Port |
|-----------|---------|------|
| Pentaho Server | 11.0.0.0-237 | 8090 |
| PostgreSQL | 15 | 5433 |

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- Minimum 8GB RAM allocated to Docker
- Pentaho Server EE license

## Project Structure

```text
pentaho-server-postgres/
├── .env                      # Environment variables
├── docker-compose-postgres.yaml
├── config/                   # Mounted as $PENTAHO_HOME
│   ├── .kettle/             # PDI/Kettle configuration
│   └── .pentaho/            # Pentaho user settings
├── db_init_postgres/        # Database initialization scripts
├── logs/                    # Tomcat logs (persistent)
└── softwareOverride/        # Configuration overrides
    ├── 1_drivers/           # JDBC drivers
    ├── 2_repository/        # Repository configuration
    ├── 3_security/          # Security settings
    ├── 4_others/            # Additional configs
    └── 99_exchange/         # File exchange folder
```

## Configuration Files

### Environment Variables (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| `PENTAHO_VERSION` | 11.0.0.0-237 | Pentaho Server version |
| `PORT` | 8090 | External HTTP port |
| `DATABASE_VERSION` | 15 | PostgreSQL version |
| `DATABASE_PORT` | 5433 | External PostgreSQL port |
| `POSTGRES_USER` | postgres | PostgreSQL admin username |
| `POSTGRES_PASSWORD` | password | PostgreSQL admin password |
| `JCR_DB_USER` | jcr_user | Jackrabbit database username |
| `JCR_DB_PASSWORD` | password | Jackrabbit database password |
| `QUARTZ_DB_USER` | pentaho_user | Quartz scheduler database username |
| `QUARTZ_DB_PASSWORD` | password | Quartz scheduler database password |
| `HIBERNATE_DB_USER` | hibuser | Hibernate database username |
| `HIBERNATE_DB_PASSWORD` | password | Hibernate database password |
| `LICENSE_URL` | (set) | Flexera license server URL |
| `JAVA_XMS` | 2048m | JVM initial heap size |
| `JAVA_XMX` | 6144m | JVM maximum heap size |

### Software Override Folders

Files in `softwareOverride/` are copied to the Pentaho installation in alphabetical order:

| Folder | Purpose |
|--------|---------|
| `1_drivers/` | PostgreSQL JDBC driver |
| `2_repository/` | Jackrabbit, Quartz, Hibernate configs |
| `3_security/` | Spring Security configuration |
| `4_others/` | Additional customizations |
| `99_exchange/` | Runtime file exchange |

## Offline Deployment

For air-gapped environments without internet access:

1. Download required files from [Hitachi Vantara Support Portal](https://support.hitachivantara.com):

   - `pentaho-server-ee-11.0.0.0-237.zip` (Required)
   - `paz-plugin-ee-11.0.0.0-237.zip` (Optional - Analyzer)
   - `pir-plugin-ee-11.0.0.0-237.zip` (Optional - Interactive Reports)
   - `pdd-plugin-ee-11.0.0.0-237.zip` (Optional - Dashboard Designer)

2. Copy files to: `assemblies/pentaho-server/stagedArtifacts/`

3. Build and deploy as shown in Quick Start

## PostgreSQL Database Details

### Connection Information

| Database | User | Password | Purpose |
|----------|------|----------|---------|
| `jackrabbit` | jcr_user | password | JCR content repository |
| `quartz` | pentaho_user | password | Scheduler jobs |
| `hibernate` | hibuser | password | Pentaho metadata |

### External Connection

```text
Host: localhost
Port: 5433
```

### Internal Connection (Docker network)

```text
Host: repository
Port: 5432
```

## Helper Scripts

### Using Makefile (Recommended)

```bash
make help           # Show all available commands
make build          # Build Pentaho Docker image
make up             # Start all services
make down           # Stop all services
make logs           # View all logs
make backup         # Backup databases
make restore        # Restore from backup
make status         # Check service health
```

### Using Bash Script

```bash
# Make script executable (first time only)
chmod +x scripts/pentaho.sh

./scripts/pentaho.sh help           # Show all commands
./scripts/pentaho.sh build          # Build Pentaho Docker image
./scripts/pentaho.sh up             # Start all services
./scripts/pentaho.sh down           # Stop all services
./scripts/pentaho.sh logs           # View all logs
./scripts/pentaho.sh backup         # Backup databases
./scripts/pentaho.sh restore        # Restore from backup
./scripts/pentaho.sh status         # Check service health
```

### Manual Docker Commands

```bash
# Start services
docker-compose -f docker-compose-postgres.yaml up -d

# Stop services
docker-compose -f docker-compose-postgres.yaml down

# View logs
docker-compose -f docker-compose-postgres.yaml logs -f pentaho-server

# Restart Pentaho Server
docker-compose -f docker-compose-postgres.yaml restart pentaho-server

# Reset database (WARNING: Deletes all data)
docker-compose -f docker-compose-postgres.yaml down -v
docker-compose -f docker-compose-postgres.yaml up -d
```

## Database Backup & Restore

### Create Backup

```bash
# Using Makefile
make backup

# Using script
./scripts/pentaho.sh backup

# Manual
docker exec pentaho-postgres pg_dumpall -U postgres > backups/backup_$(date +%Y%m%d).sql
```

### Restore Backup

```bash
# Using Makefile
make restore

# Using script
./scripts/pentaho.sh restore

# Manual
cat backups/backup.sql | docker exec -i pentaho-postgres psql -U postgres
```

## Accessing the Server

| URL | Description |
|-----|-------------|
| <http://localhost:8090/pentaho> | Pentaho User Console (PUC) |
| <http://localhost:8090/pentaho/api> | REST API |
| <http://localhost:8090/pentaho/kettle> | Carte/PDI Server |

### Default Credentials

| Username | Password | Role |
|----------|----------|------|
| admin | password | Administrator |
| suzy | password | Power User |
| pat | password | Business Analyst |
| tiffany | password | Report Author |

## Troubleshooting

### Container won't start

```bash
# Check container status
docker-compose -f docker-compose-postgres.yaml ps

# Check logs for errors
docker-compose -f docker-compose-postgres.yaml logs pentaho-server
```

### Database connection errors

1. Ensure PostgreSQL container is running and healthy
2. Wait 30-60 seconds for database initialization on first start
3. Check `context.xml` JDBC URLs point to `repository:5432`

### Out of memory errors

Increase JVM heap in `docker-compose-postgres.yaml`:

```yaml
environment:
  JAVA_XMS: "4096m"
  JAVA_XMX: "8192m"
```

### License issues

1. Verify `LICENSE_URL` in `.env` is correct
2. Check network connectivity to Flexera license server
3. Review logs: `docker-compose logs pentaho-server | grep -i license`
