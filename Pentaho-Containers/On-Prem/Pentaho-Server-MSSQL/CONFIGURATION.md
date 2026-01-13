# Pentaho Server 11 Configuration Guide (SQL Server)

This document provides detailed configuration information for Pentaho Server 11 with Microsoft SQL Server repository.

## Table of Contents

- [Environment Variables](#environment-variables)
- [Database Configuration](#database-configuration)
- [SQL Server Editions](#sql-server-editions)
- [JDBC Driver](#jdbc-driver)
- [Security Configuration](#security-configuration)
- [Performance Tuning](#performance-tuning)
- [Backup Configuration](#backup-configuration)
- [Troubleshooting Configuration](#troubleshooting-configuration)
- [Additional Resources](#additional-resources)

## Environment Variables

All configuration is managed through the `.env` file. Copy from `.env.template` to get started:

```bash
cp .env.template .env
```

### Pentaho Version

```bash
PENTAHO_VERSION=11.0.0.0-237
```
Must match the ZIP file in `docker/stagedArtifacts/`

### Docker Image Settings

```bash
PENTAHO_IMAGE_NAME=pentaho/pentaho-server
PENTAHO_IMAGE_TAG=11.0.0.0-237
```

### SQL Server Configuration

```bash
# SA password (MUST meet complexity requirements!)
MSSQL_SA_PASSWORD=YourStr0ng!Passw0rd

# SQL Server Edition
MSSQL_PID=Developer  # Options: Developer, Express, Standard, Enterprise

# Port
MSSQL_PORT=1433
```

**Password Requirements:**
- Minimum 8 characters
- Must contain uppercase letters
- Must contain lowercase letters
- Must contain numbers
- Must contain special characters

### Pentaho Server Ports

```bash
PENTAHO_HTTP_PORT=8090   # Web interface
PENTAHO_HTTPS_PORT=8443  # HTTPS (when configured)
```

### JVM Memory Settings

```bash
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m
```

Adjust based on:
- Available system RAM
- Expected workload
- Number of concurrent users

## Database Configuration

### Connection Details

| Database | User | Password | Purpose |
|----------|------|----------|---------|
| jackrabbit | jcr_user | password | JCR content repository |
| quartz | pentaho_user | password | Scheduler |
| hibernate | hibuser | password | Repository, audit, operations |
| pentaho_dilogs | hibuser | password | ETL logging |
| pentaho_operations_mart | hibuser | password | Operations analytics |

### JDBC Connection Strings

Format:
```
jdbc:sqlserver://repository:1433;databaseName={database};encrypt=false;trustServerCertificate=true
```

### Configuration Files

**Context.xml** - `softwareOverride/2_repository/tomcat/webapps/pentaho/META-INF/context.xml`
- Defines JNDI datasources
- Uses Microsoft SQL Server JDBC driver: `com.microsoft.sqlserver.jdbc.SQLServerDriver`

**Hibernate Settings** - `softwareOverride/2_repository/pentaho-solutions/system/hibernate/hibernate-settings.xml`
- Points to: `system/hibernate/sqlserver.hibernate.cfg.xml`

**Repository.xml** - `softwareOverride/2_repository/pentaho-solutions/system/jackrabbit/repository.xml`
- Uses `MSSqlPersistenceManager` for JCR storage
- Schema: `mssql`

## SQL Server Editions

### Developer Edition (Default)
- Free for development/testing
- Full Enterprise features
- **Not licensed for production use**

### Express Edition
- Free
- Limited to 10GB per database
- Limited CPU and memory usage
- Good for small deployments

### Standard Edition
- Licensed software
- Supports up to 24 cores and 128GB RAM
- Production ready

### Enterprise Edition
- Licensed software
- Unlimited resources
- Advanced features (Always On, partitioning, etc.)

## JDBC Driver

### Required Version
Microsoft JDBC Driver 12.x or later for SQL Server 2022

### Installation
```bash
cd softwareOverride/1_drivers/tomcat/lib/
wget https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar
```

### Verification
```bash
ls -lh softwareOverride/1_drivers/tomcat/lib/mssql-jdbc-*.jar
```

## Security Configuration

### Change Default Passwords

**1. SQL Server SA Password**

Edit `.env`:
```bash
MSSQL_SA_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)@1Aa
```

Update database initialization scripts:
```bash
# Update all occurrences of 'password' in:
db_init_mssql/*.sql
```

**2. Application User Passwords**

Update in both:
- `db_init_mssql/*.sql` (database users)
- `softwareOverride/2_repository/tomcat/webapps/pentaho/META-INF/context.xml` (JDBC datasources)

**3. Pentaho Admin User**

Change via Pentaho web interface after first login or using Pentaho encr utility.

### Restrict Database Port

Edit `docker-compose.yml`:
```yaml
mssql:
  # Remove or comment out ports section to prevent external access
  # ports:
  #   - "${MSSQL_PORT:-1433}:1433"
```

## Performance Tuning

### SQL Server Configuration

Create `mssql-config/mssql.conf`:
```ini
[memory]
memorylimitmb = 4096

[sqlagent]
enabled = true
```

### JVM Tuning

For high-load environments, edit `.env`:
```bash
PENTAHO_MIN_MEMORY=4096m
PENTAHO_MAX_MEMORY=8192m
```

### Docker Resources

Allocate sufficient resources in Docker Desktop or daemon configuration.

## Backup Configuration

### Automated Backups

Setup cron job:
```bash
crontab -e
```

Add:
```cron
# Daily backup at 2 AM
0 2 * * * /home/pentaho/Pentaho-Server-MSSQL/scripts/backup-mssql.sh

# Weekly cleanup (keep 30 days)
0 3 * * 0 find /home/pentaho/Pentaho-Server-MSSQL/backups/ -name "*.tar.gz" -mtime +30 -delete
```

## Troubleshooting Configuration

### View Active Configuration

```bash
# SQL Server configuration
docker exec pentaho-mssql cat /var/opt/mssql/mssql.conf

# Pentaho environment
docker exec pentaho-server env | grep PENTAHO
```

### Test Database Connections

```bash
# From Pentaho container
docker exec -it pentaho-server bash -c "
  curl -f http://repository:1433 && echo 'MSSQL reachable' || echo 'MSSQL unreachable'
"
```

### Verify JDBC Driver

```bash
docker exec pentaho-server ls -lh /opt/pentaho/pentaho-server/tomcat/lib/mssql-jdbc-*.jar
```

## Additional Resources

- [SQL Server Configuration](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-configure-mssql-conf)
- [Microsoft JDBC Driver Documentation](https://learn.microsoft.com/en-us/sql/connect/jdbc/microsoft-jdbc-driver-for-sql-server)
- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)

## Related Documentation

- [README.md](README.md) - Complete deployment guide
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Project overview and status
