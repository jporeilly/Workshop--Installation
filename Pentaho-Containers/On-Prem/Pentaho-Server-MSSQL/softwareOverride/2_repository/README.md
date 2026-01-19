# 2_repository - Database Repository Configuration

## Purpose

This directory contains configuration files for Pentaho's internal repositories and database connections. It configures how Pentaho connects to and uses Microsoft SQL Server for:

- **JackRabbit** - Content repository (reports, dashboards, data sources)
- **Quartz** - Job scheduler
- **Hibernate** - Pentaho metadata repository

## Processing Order

This directory is processed **second** during container startup, after JDBC drivers are in place.

## Directory Structure

```
2_repository/
├── README.md                                    # This file
├── pentaho-solutions/
│   └── system/
│       ├── audit_sql.xml                        # Audit logging SQL queries
│       ├── hibernate/
│       │   └── hibernate-settings.xml           # Hibernate ORM configuration
│       ├── jackrabbit/
│       │   └── repository.xml                   # JCR repository settings
│       ├── repository.spring.properties         # Repository Spring config
│       └── scheduler-plugin/
│           └── quartz/
│               └── quartz.properties            # Job scheduler config
└── tomcat/
    └── webapps/
        └── pentaho/
            └── META-INF/
                └── context.xml                  # JNDI datasource definitions
```

## Key Configuration Files

### context.xml (JNDI DataSources)

**Location:** `tomcat/webapps/pentaho/META-INF/context.xml`

Defines JNDI datasources for database connections:

```xml
<Resource name="jdbc/Hibernate"
          type="javax.sql.DataSource"
          url="jdbc:sqlserver://repository:1433;databaseName=hibernate;encrypt=false;trustServerCertificate=true"
          username="hibuser"
          password="password"/>

<Resource name="jdbc/Quartz"
          type="javax.sql.DataSource"
          url="jdbc:sqlserver://repository:1433;databaseName=quartz;encrypt=false;trustServerCertificate=true"
          username="pentaho_user"
          password="password"/>
```

### repository.xml (JackRabbit)

**Location:** `pentaho-solutions/system/jackrabbit/repository.xml`

Configures the JCR content repository:
- Database connection settings
- Clustering options
- Search indexing
- Workspace configuration

### quartz.properties

**Location:** `pentaho-solutions/system/scheduler-plugin/quartz/quartz.properties`

Configures the Quartz job scheduler:
- Database driver and connection
- Thread pool settings
- Job store configuration

### hibernate-settings.xml

**Location:** `pentaho-solutions/system/hibernate/hibernate-settings.xml`

Configures Hibernate ORM for Pentaho metadata:
- Database dialect
- Connection pooling
- Transaction management

## JDBC Datasources

| Resource Name | Database | User | Purpose |
|---------------|----------|------|---------|
| `jdbc/Hibernate` | hibernate | hibuser | Hibernate repository |
| `jdbc/Audit` | hibernate | hibuser | Audit logging |
| `jdbc/Quartz` | quartz | pentaho_user | Quartz scheduler |
| `jdbc/PDI_Operations_Mart` | hibernate | hibuser | PDI operations mart |
| `jdbc/pentaho_operations_mart` | hibernate | hibuser | Pentaho operations mart |
| `jdbc/live_logging_info` | pentaho_dilogs | hibuser | Live logging |
| `jdbc/jackrabbit` | jackrabbit | jcr_user | JackRabbit content repository |
| `jdbc/SampleData` | sampledata | sa | Sample data (HSQLDB) |

## SQL Server-specific Settings

| Setting | Value |
|---------|-------|
| JDBC Driver | `com.microsoft.sqlserver.jdbc.SQLServerDriver` |
| Default Port | `1433` |
| Database Host | `repository` (container name) |
| Quartz delegate | `org.quartz.impl.jdbcjobstore.MSSQLDelegate` |
| Quartz table prefix | `QRTZ6_` |
| Hibernate config | `sqlserver.hibernate.cfg.xml` |
| Validation query | `select 1` |
| Encryption | `encrypt=false;trustServerCertificate=true` |

## Connection Pool Settings

Default pool configuration in `context.xml`:

| Setting | Value |
|---------|-------|
| maxActive | 20 |
| maxIdle | 5 |
| minIdle | 0 |
| initialSize | 0 |
| maxWait | 10000 ms |

## Admin Users

Configured in `repository.spring.properties`:

| User | Role |
|------|------|
| admin | Single tenant admin |
| pentahoRepoAdmin | Repository admin |
| super | Super admin |
| system | System tenant admin |

## Connection String Format

```
jdbc:sqlserver://repository:1433;databaseName=<database>;encrypt=false;trustServerCertificate=true
```

## Customization

### Changing Database Passwords

1. Update SQL initialization scripts in `db_init_mssql/`
2. Update `context.xml` with new passwords
3. Recreate SQL Server volume and restart:
   ```bash
   docker compose down -v
   docker compose up -d
   ```

### Enabling Encryption

To enable encrypted connections:

1. Configure SQL Server with a valid certificate
2. Update connection URLs in `context.xml`:
   ```
   encrypt=true;trustServerCertificate=false
   ```
3. Import the server certificate into the Java truststore

### Using Different Database

To use PostgreSQL instead of SQL Server:

1. Add PostgreSQL driver to `1_drivers/tomcat/lib/`
2. Update `context.xml` with PostgreSQL JDBC URL
3. Update `repository.xml`, `quartz.properties`, `hibernate-settings.xml`
4. Create PostgreSQL initialization scripts

## Troubleshooting

### Connection Refused

```
The TCP/IP connection to the host repository, port 1433 has failed
```

**Cause:** SQL Server not ready or incorrect hostname
**Solution:** Verify SQL Server container is healthy: `docker compose ps`

### Unknown Database

```
Cannot open database "hibernate" requested by the login
```

**Cause:** Database initialization scripts didn't run
**Solution:** Recreate SQL Server volume: `docker compose down -v && docker compose up -d`

### Login Failed

```
Login failed for user 'hibuser'
```

**Cause:** Password mismatch between context.xml and database
**Solution:** Verify passwords match in `context.xml` and database init scripts

### Quartz Errors

```
Invalid object name 'QRTZ6_LOCKS'
```

**Cause:** Quartz tables not created
**Solution:** Verify `QRTZ6_*` tables exist in the `quartz` database

### SSL/TLS Errors

```
The driver could not establish a secure connection to SQL Server
```

**Cause:** Encryption settings mismatch
**Solution:** Ensure `encrypt=false;trustServerCertificate=true` in connection URLs for non-SSL connections

### Container Networking

**Cause:** Pentaho and SQL Server not on the same Docker network
**Solution:** Ensure both containers are defined in the same `docker-compose.yml`

## Related Documentation

- [Main README](../../README.md) - Project overview
- [softwareOverride README](../README.md) - Override system documentation
- [ARCHITECTURE.md](../../ARCHITECTURE.md) - Database schema details
