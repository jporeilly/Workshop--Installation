# Pentaho Server 11 Configuration Guide (Oracle)

This document provides detailed configuration information for Pentaho Server 11 with Oracle Database repository.

## Table of Contents

- [Environment Variables](#environment-variables)
- [Database Configuration](#database-configuration)
- [Oracle Edition Comparison](#oracle-edition-comparison)
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

### Oracle Configuration

```bash
# Oracle password
ORACLE_PASSWORD=password  # Change for production!

# Oracle port
ORACLE_PORT=1521
```

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

| Schema | User | Password | Purpose |
|--------|------|----------|---------|
| jcr_user | jcr_user | password | JCR content repository |
| pentaho_user | pentaho_user | password | Quartz scheduler |
| hibuser | hibuser | password | Repository, audit, operations |

### JDBC Connection Strings

Format:
```
jdbc:oracle:thin:@//repository:1521/FREEPDB1
```

### Configuration Files

**Context.xml** - `softwareOverride/2_repository/tomcat/webapps/pentaho/META-INF/context.xml`
- Defines JNDI datasources
- Uses Oracle JDBC driver: `oracle.jdbc.OracleDriver`

**Hibernate Settings** - `softwareOverride/2_repository/pentaho-solutions/system/hibernate/hibernate-settings.xml`
- Points to: `system/hibernate/oracle10g.hibernate.cfg.xml`

**Repository.xml** - `softwareOverride/2_repository/pentaho-solutions/system/jackrabbit/repository.xml`
- Uses `OraclePersistenceManager` for JCR storage
- Schema: `oracle`

## Oracle Edition Comparison

### Free Edition (Default)

- Free for development and production
- 12GB user data limit
- 2GB RAM limit
- 2 CPU threads
- No support included

### Standard Edition

- Licensed software
- No data/resource limits
- Basic replication features
- Oracle support available

### Enterprise Edition

- Licensed software
- Advanced features (RAC, Data Guard, Partitioning)
- Full Oracle support
- Recommended for mission-critical deployments

## JDBC Driver

### Required Version

Oracle JDBC Driver ojdbc11.jar (for JDK 11+)

### Installation

```bash
# Download from Oracle website
# https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html

cp ojdbc11.jar softwareOverride/1_drivers/tomcat/lib/
```

### Verification

```bash
ls -lh softwareOverride/1_drivers/tomcat/lib/ojdbc*.jar
```

## Security Configuration

### Change Default Passwords

**1. Oracle Password**

Edit `.env`:
```bash
ORACLE_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
```

Update database initialization scripts:
```bash
# Update all occurrences of 'password' in:
db_init_oracle/*.sql
```

**2. Application User Passwords**

Update in both:
- `db_init_oracle/*.sql` (database users)
- `softwareOverride/2_repository/tomcat/webapps/pentaho/META-INF/context.xml` (JDBC datasources)

**3. Pentaho Admin User**

Change via Pentaho web interface after first login.

### Restrict Database Port

Edit `docker-compose.yml`:
```yaml
oracle:
  # Remove or comment out ports section to prevent external access
  # ports:
  #   - "${ORACLE_PORT:-1521}:1521"
```

## Performance Tuning

### Oracle Configuration

Oracle Free edition has built-in resource limits. For tuning Standard/Enterprise:

```sql
-- Increase processes
ALTER SYSTEM SET processes=300 SCOPE=SPFILE;

-- Increase sessions
ALTER SYSTEM SET sessions=335 SCOPE=SPFILE;
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
0 2 * * * /home/pentaho/Pentaho-Server-Oracle/scripts/backup-oracle.sh

# Weekly cleanup (keep 30 days)
0 3 * * 0 find /home/pentaho/Pentaho-Server-Oracle/backups/ -name "*.dmp" -mtime +30 -delete
```

### Data Pump Configuration

Backups use Oracle Data Pump (expdp/impdp) for efficient schema export/import.

## Troubleshooting Configuration

### View Active Configuration

```bash
# Oracle configuration
docker exec pentaho-oracle sqlplus -s sys/password@//localhost:1521/FREEPDB1 as sysdba <<< "SHOW PARAMETER;"

# Pentaho environment
docker exec pentaho-server env | grep PENTAHO
```

### Test Database Connections

```bash
# From Pentaho container
docker exec -it pentaho-server bash -c "
  curl -f http://repository:1521 && echo 'Oracle reachable' || echo 'Oracle unreachable'
"
```

### Verify JDBC Driver

```bash
docker exec pentaho-server ls -lh /opt/pentaho/pentaho-server/tomcat/lib/ojdbc*.jar
```

### Check Oracle Tablespace Usage

```bash
docker exec pentaho-oracle sqlplus -s sys/password@//localhost:1521/FREEPDB1 as sysdba <<< "
SELECT tablespace_name,
       ROUND(SUM(bytes)/1024/1024,2) AS size_mb,
       ROUND(SUM(maxbytes)/1024/1024,2) AS max_mb
FROM dba_data_files
GROUP BY tablespace_name;
"
```

## Additional Resources

- [Oracle Database 23c Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/23/)
- [Oracle JDBC Driver Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/21/jjdbc/)
- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)

## Related Documentation

- [README.md](README.md) - Complete deployment guide
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Project overview and status
