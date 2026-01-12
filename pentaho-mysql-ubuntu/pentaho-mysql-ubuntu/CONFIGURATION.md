# Configuration Reference

This document provides a comprehensive reference for all configurable options in the Pentaho Server Docker deployment.

## Table of Contents

- [Environment Variables](#environment-variables)
- [JVM Memory Tuning](#jvm-memory-tuning)
- [MySQL Configuration](#mysql-configuration)
- [Security Configuration](#security-configuration)
- [JDBC Driver Management](#jdbc-driver-management)
- [Production vs Development](#production-vs-development)

## Environment Variables

All environment variables are defined in the `.env` file. Create it from the template:

```bash
cp .env.template .env
```

### Pentaho Version

| Variable | Default | Description |
|----------|---------|-------------|
| `PENTAHO_VERSION` | `11.0.0.0-237` | Pentaho Server version (must match ZIP filename) |

### Docker Image Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `PENTAHO_IMAGE_NAME` | `pentaho/pentaho-server` | Docker image name |
| `PENTAHO_IMAGE_TAG` | `${PENTAHO_VERSION}` | Docker image tag |

### MySQL Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MYSQL_ROOT_PASSWORD` | `password` | MySQL root password (CHANGE FOR PRODUCTION) |
| `MYSQL_PORT` | `3306` | MySQL external port |

### Port Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PENTAHO_HTTP_PORT` | `8090` | Pentaho HTTP port (external) |
| `PENTAHO_HTTPS_PORT` | `8443` | Pentaho HTTPS port (external) |
| `ADMINER_PORT` | `8050` | Adminer web UI port |

### JVM Memory Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `PENTAHO_MIN_MEMORY` | `2048m` | Minimum JVM heap size |
| `PENTAHO_MAX_MEMORY` | `4096m` | Maximum JVM heap size |

### License Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `LICENSE_URL` | (empty) | URL to download EE license file |

### Installation Paths

| Variable | Default | Description |
|----------|---------|-------------|
| `INSTALLATION_PATH` | `/opt/pentaho` | Pentaho installation root |
| `PENTAHO_SERVER_PATH` | `${INSTALLATION_PATH}/pentaho-server` | Pentaho Server path |

## JVM Memory Tuning

### Recommended Settings by Workload

| Workload | Host RAM | MIN_MEMORY | MAX_MEMORY |
|----------|----------|------------|------------|
| Development | 8GB | 1024m | 2048m |
| Small (< 10 users) | 16GB | 2048m | 4096m |
| Medium (10-50 users) | 32GB | 4096m | 8192m |
| Large (50+ users) | 64GB+ | 8192m | 16384m |

### Setting JVM Options

Edit `.env`:
```bash
PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=8192m
```

Additional JVM options can be set in `docker-compose.yml` under `environment`:
```yaml
environment:
  - CATALINA_OPTS=-Xms${PENTAHO_MIN_MEMORY} -Xmx${PENTAHO_MAX_MEMORY} -Dfile.encoding=utf8
```

### Garbage Collection Tuning

For large deployments, consider adding GC options:
```yaml
environment:
  - CATALINA_OPTS=-Xms4g -Xmx8g -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

## MySQL Configuration

### Custom Configuration File

Edit `mysql-config/custom.cnf`:

```ini
[mysqld]
# Character Set
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# Connection Settings
max_connections=200
wait_timeout=28800

# InnoDB Settings
innodb_buffer_pool_size=512M
innodb_log_file_size=256M
innodb_flush_log_at_trx_commit=1

# Query Cache (deprecated in MySQL 8.0)
# query_cache_type=0
# query_cache_size=0

# Logging
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow.log
long_query_time=2

# Binary Logging (for replication/backup)
log-bin=mysql-bin
binlog_format=ROW
expire_logs_days=7

# Timezone
default-time-zone='+00:00'
```

### Tuning Recommendations

| Setting | Small | Medium | Large |
|---------|-------|--------|-------|
| `max_connections` | 100 | 200 | 500 |
| `innodb_buffer_pool_size` | 256M | 512M | 2G |
| `innodb_log_file_size` | 128M | 256M | 512M |

### Database User Configuration

Database users are created by the initialization scripts in `db_init_mysql/`:

| Database | User | Default Password |
|----------|------|------------------|
| jackrabbit | jcr_user | password |
| quartz | quartz_user | password |
| hibernate | hibuser | password |
| pentaho_logging | pentaho_user | password |
| pentaho_mart | pentaho_user | password |

**IMPORTANT:** Change these passwords for production deployments by editing the SQL files.

## Security Configuration

### Authentication Methods

Pentaho supports multiple authentication backends configured in `softwareOverride/3_security/`:

#### Memory-Based (Default - Development Only)

Users defined in XML file:
```xml
<!-- applicationContext-spring-security-memory.xml -->
<user name="admin" password="{SHA}..." authorities="Administrator"/>
```

#### Hibernate-Based (Production Recommended)

Users stored in database:
```properties
# applicationContext-spring-security-hibernate.properties
datasource.driver.classname=com.mysql.cj.jdbc.Driver
datasource.url=jdbc:mysql://repository:3306/hibernate
datasource.username=hibuser
datasource.password=password
```

#### LDAP Integration

Configure LDAP connection:
```properties
# applicationContext-spring-security-ldap.properties
contextSource.providerUrl=ldap://ldap.example.com:389
contextSource.userDn=cn=admin,dc=example,dc=com
contextSource.password=ldap_password
```

### Changing Default Passwords

#### 1. Pentaho Admin Password

After first login, change via web UI:
1. Login as admin
2. Navigate to Administration > Users
3. Edit admin user and change password

Or via API:
```bash
curl -u admin:password -X PUT \
  "http://localhost:8090/pentaho/api/userroledao/updatePassword" \
  -d "userName=admin&newPassword=newSecurePassword"
```

#### 2. MySQL Passwords

Edit `.env` and SQL initialization files, then recreate containers:
```bash
# Update .env
MYSQL_ROOT_PASSWORD=newSecureRootPassword

# Update db_init_mysql/*.sql files with new passwords
# Then recreate MySQL volume
docker compose down -v
docker compose up -d
```

### SSL/TLS Configuration

#### 1. Obtain Certificates

Using Let's Encrypt:
```bash
certbot certonly --standalone -d pentaho.example.com
```

#### 2. Configure Tomcat

Create `softwareOverride/4_others/tomcat/conf/server.xml` with HTTPS connector:
```xml
<Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"
           maxThreads="150" SSLEnabled="true">
    <SSLHostConfig>
        <Certificate certificateKeystoreFile="/opt/pentaho/keystore.jks"
                     type="RSA" />
    </SSLHostConfig>
</Connector>
```

#### 3. Mount Certificates

Add to `docker-compose.yml`:
```yaml
volumes:
  - ./certs/keystore.jks:/opt/pentaho/keystore.jks:ro
```

## JDBC Driver Management

### Included Drivers

| Driver | Version | Location |
|--------|---------|----------|
| MySQL Connector/J | 8.3.0 | `softwareOverride/1_drivers/tomcat/lib/` |

### Adding New JDBC Drivers

1. Download the driver JAR
2. Place in `softwareOverride/1_drivers/tomcat/lib/`
3. Rebuild container:
   ```bash
   docker compose build --no-cache pentaho-server
   docker compose up -d pentaho-server
   ```

### Supported Databases

| Database | Driver | Download |
|----------|--------|----------|
| MySQL 8.x | mysql-connector-j-8.3.0.jar | [Maven Central](https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/) |
| PostgreSQL | postgresql-42.x.x.jar | [Maven Central](https://repo1.maven.org/maven2/org/postgresql/postgresql/) |
| Oracle | ojdbc11.jar | [Oracle Downloads](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html) |
| SQL Server | mssql-jdbc-12.x.x.jar | [Microsoft Downloads](https://docs.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server) |
| MariaDB | mariadb-java-client-3.x.x.jar | [Maven Central](https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/) |

### JDBC Connection URLs

| Database | URL Format |
|----------|------------|
| MySQL | `jdbc:mysql://host:3306/database` |
| PostgreSQL | `jdbc:postgresql://host:5432/database` |
| Oracle | `jdbc:oracle:thin:@host:1521:SID` |
| SQL Server | `jdbc:sqlserver://host:1433;databaseName=database` |

## Production vs Development

### Development Configuration

```bash
# .env
PENTAHO_MIN_MEMORY=1024m
PENTAHO_MAX_MEMORY=2048m
MYSQL_ROOT_PASSWORD=password
```

Features enabled:
- Adminer database admin
- MySQL port exposed
- Default passwords
- Debug logging

### Production Configuration

```bash
# .env
PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=8192m
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
```

Recommended changes:
1. **Disable Adminer** - Comment out in `docker-compose.yml`
2. **Remove MySQL port exposure** - Comment out ports section
3. **Change all passwords** - MySQL, Pentaho admin, database users
4. **Enable SSL/TLS** - Configure HTTPS connector
5. **Set up backups** - Configure automated backup schedule
6. **Enable monitoring** - Add health check endpoints
7. **Configure firewall** - Allow only necessary ports

### Production docker-compose.yml Changes

```yaml
services:
  pentaho-server:
    # Add resource limits
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
    # Add restart policy
    restart: unless-stopped

  mysql:
    # Remove external port exposure
    # ports:
    #   - "${MYSQL_PORT:-3306}:3306"
    restart: unless-stopped

  # Remove or comment out Adminer
  # adminer:
  #   ...
```

## Makefile Targets

Use `make help` to see all available targets:

```bash
make help          # Show all targets
make deploy        # Full deployment
make build         # Build images
make up            # Start services
make down          # Stop services
make logs          # View logs
make backup        # Backup database
make restore       # Restore database
make validate      # Validate deployment
make clean         # Clean up containers
```

## Related Documentation

- [README.md](README.md) - Quick start guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving
- [softwareOverride/README.md](softwareOverride/README.md) - Override system
