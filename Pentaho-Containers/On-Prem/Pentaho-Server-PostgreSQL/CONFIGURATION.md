# Configuration Guide

## Environment Variables

All configuration is managed through the `.env` file.

### Pentaho Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `PENTAHO_VERSION` | 11.0.0.0-237 | Pentaho package version |
| `PENTAHO_HTTP_PORT` | 8090 | HTTP port for web interface |
| `PENTAHO_HTTPS_PORT` | 8443 | HTTPS port (requires SSL config) |
| `PENTAHO_MIN_MEMORY` | 2048m | JVM minimum heap size |
| `PENTAHO_MAX_MEMORY` | 4096m | JVM maximum heap size |
| `LICENSE_URL` | (empty) | URL to enterprise license file |

### PostgreSQL Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_PASSWORD` | password | PostgreSQL superuser password |
| `POSTGRES_PORT` | 5432 | PostgreSQL port |

## PostgreSQL Configuration

PostgreSQL server settings are in `postgres-config/custom.conf`:

```conf
# Connection limits
max_connections = 200

# Memory (adjust based on available RAM)
shared_buffers = 256MB
effective_cache_size = 768MB
work_mem = 16MB

# Performance
random_page_cost = 1.1
effective_io_concurrency = 200
```

## Pentaho Repository Configuration

### JDBC Connections

Located in `softwareOverride/2_repository/tomcat/webapps/pentaho/META-INF/context.xml`:

- Driver: `org.postgresql.Driver`
- URL format: `jdbc:postgresql://repository:5432/{database}`

### Jackrabbit Repository

Located in `softwareOverride/2_repository/pentaho-solutions/system/jackrabbit/repository.xml`:

- Uses `PostgreSQLPersistenceManager`
- Schema: `postgresql`

### Quartz Scheduler

Located in `softwareOverride/2_repository/pentaho-solutions/system/scheduler-plugin/quartz/quartz.properties`:

- Delegate: `org.quartz.impl.jdbcjobstore.PostgreSQLDelegate`
- Table prefix: `QRTZ6_`

### Hibernate

Located in `softwareOverride/2_repository/pentaho-solutions/system/hibernate/hibernate-settings.xml`:

- Config file: `system/hibernate/postgresql.hibernate.cfg.xml`

## Security Configuration

Default security uses in-memory authentication.

### Default Credentials

| User | Password | Role |
|------|----------|------|
| admin | password | Administrator |
| suzy | password | Power User |
| pat | password | Business Analyst |

### Security Providers

Files in `softwareOverride/3_security/`:

- `applicationContext-spring-security-memory.xml` - In-memory (default)
- `applicationContext-spring-security-hibernate.properties` - Database-backed

## JVM Tuning

Set memory in `.env`:

```bash
# For small deployments (4GB RAM)
PENTAHO_MIN_MEMORY=1024m
PENTAHO_MAX_MEMORY=2048m

# For medium deployments (8GB RAM)
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m

# For large deployments (16GB+ RAM)
PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=8192m
```

## Production Recommendations

1. **Change default passwords**
   ```bash
   POSTGRES_PASSWORD=strong_random_password
   ```

2. **Restrict port exposure**
   - Remove PostgreSQL port mapping from docker-compose.yml

3. **Enable HTTPS**
   - Configure SSL certificates in Tomcat
   - Use reverse proxy (nginx, traefik)

4. **Backup regularly**
   ```bash
   # Add to crontab
   0 2 * * * /path/to/scripts/backup-postgres.sh
   ```

5. **Monitor resources**
   ```bash
   make stats
   ```
