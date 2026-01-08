# Pentaho Server 11 with PostgreSQL 17 - Docker Deployment Guide

## Prerequisites

- Docker Engine 24.0+
- Docker Compose v2.20+
- Pentaho Server 11.0.0.0-237 distribution ZIP file
- PostgreSQL JDBC driver (postgresql-42.7.8.jar)

## Quick Start

### 1. Download Required Files

**Pentaho Server Distribution:**
```bash
# Place in assemblies/pentaho-server/stagedArtifacts/
# File: pentaho-server-ce-11.0.0.0-237.zip (or pentaho-server-ee-*.zip)
```

**PostgreSQL JDBC Driver:**
```bash
cd dist/on-prem/pentaho-server/pentaho-server-postgres/softwareOverride/1_drivers/tomcat/lib/
curl -L -o postgresql-42.7.8.jar https://jdbc.postgresql.org/download/postgresql-42.7.8.jar
```

### 2. Build and Deploy

```bash
cd dist/on-prem/pentaho-server/pentaho-server-postgres

# Build and start containers
docker-compose -f docker-compose-postgres.yaml up --build -d

# View logs
docker-compose -f docker-compose-postgres.yaml logs -f
```

### 3. Access Pentaho Server

- **URL:** http://localhost:8090/pentaho
- **Username:** admin
- **Password:** password

## Project Structure

```
on-prem-11.0.0.0-237/
├── assemblies/pentaho-server/
│   ├── Dockerfile                    # Pentaho Server image
│   ├── stagedArtifacts/              # Place ZIP here
│   └── entrypoint/
│       └── docker-entrypoint.sh      # Container init script
│
└── dist/on-prem/pentaho-server/pentaho-server-postgres/
    ├── .env                          # Environment configuration
    ├── docker-compose-postgres.yaml  # Docker Compose file
    ├── db_init_postgres/             # PostgreSQL init scripts
    ├── softwareOverride/             # Configuration overrides
    │   ├── 1_drivers/                # JDBC drivers
    │   └── 2_repository/             # Repository configs
    ├── config/                       # Pentaho home config
    └── logs/                         # Tomcat logs
```

## Configuration

### Environment Variables (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| PENTAHO_VERSION | 11.0.0.0-237 | Pentaho version |
| DATABASE_VERSION | 17 | PostgreSQL version |
| PORT | 8090 | Exposed HTTP port |
| PENTAHO_HOME | /home/pentaho | Pentaho home directory |

### Database Credentials

**Default credentials (change for production!):**

| Database | User | Password |
|----------|------|----------|
| jackrabbit | jcr_user | password |
| quartz | pentaho_user | password |
| hibernate | hibuser | password |

## Commands

```bash
# Start containers
docker-compose -f docker-compose-postgres.yaml up -d

# Stop containers
docker-compose -f docker-compose-postgres.yaml down

# View Pentaho logs
docker-compose -f docker-compose-postgres.yaml logs -f pentaho-server

# View PostgreSQL logs
docker-compose -f docker-compose-postgres.yaml logs -f repository

# Rebuild after changes
docker-compose -f docker-compose-postgres.yaml up --build -d

# Remove volumes (clean install)
docker-compose -f docker-compose-postgres.yaml down -v
```

## Troubleshooting

### Container won't start
```bash
# Check container status
docker-compose -f docker-compose-postgres.yaml ps

# Check logs for errors
docker-compose -f docker-compose-postgres.yaml logs pentaho-server
```

### Database connection issues
```bash
# Verify PostgreSQL is running
docker exec pentaho-postgres-17 pg_isready -U postgres

# Check database initialization
docker exec pentaho-postgres-17 psql -U postgres -c "\l"
```

### Reset everything
```bash
docker-compose -f docker-compose-postgres.yaml down -v
docker-compose -f docker-compose-postgres.yaml up --build -d
```

## Production Considerations

1. **Change all default passwords** in:
   - `.env` file
   - `db_init_postgres/*.sql` files
   - `softwareOverride/2_repository/` config files

2. **Enable HTTPS** - Configure Tomcat SSL or use a reverse proxy

3. **Backup volumes** - Regularly backup `repository-data` volume

4. **Resource limits** - Adjust CPU/memory in docker-compose.yaml

5. **Licensing** - Apply valid Pentaho license after first login
