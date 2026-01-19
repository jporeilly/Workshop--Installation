# 2_repository - Database Repository Configuration

## Purpose

This directory contains configuration files for Pentaho's internal repositories and database connections. It configures how Pentaho connects to and uses Oracle Database for:

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
│       ├── hibernate/
│       │   └── hibernate-settings.xml           # Hibernate ORM configuration
│       ├── jackrabbit/
│       │   └── repository.xml                   # JCR repository settings
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
          url="jdbc:oracle:thin:@//repository:1521/FREEPDB1"
          username="hibuser"
          password="password"/>

<Resource name="jdbc/Quartz"
          type="javax.sql.DataSource"
          url="jdbc:oracle:thin:@//repository:1521/FREEPDB1"
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

| Resource Name | Database/Schema | User | Purpose |
|---------------|-----------------|------|---------|
| `jdbc/Hibernate` | FREEPDB1 | hibuser | Hibernate repository |
| `jdbc/Audit` | FREEPDB1 | hibuser | Audit logging |
| `jdbc/Quartz` | FREEPDB1 | pentaho_user | Quartz scheduler |
| `jdbc/PDI_Operations_Mart` | FREEPDB1 | hibuser | PDI operations mart |
| `jdbc/pentaho_operations_mart` | FREEPDB1 | hibuser | Pentaho operations mart |
| `jdbc/live_logging_info` | FREEPDB1 | hibuser | Live logging |
| `jdbc/jackrabbit` | FREEPDB1 | jcr_user | JackRabbit content repository |
| `jdbc/SampleData` | sampledata | sa | Sample data (HSQLDB) |

## Oracle-specific Settings

| Setting | Value |
|---------|-------|
| JDBC Driver | `oracle.jdbc.OracleDriver` |
| Default Port | `1521` |
| Database Host | `repository` (container name) |
| Service Name | `FREEPDB1` |
| Quartz delegate | `org.quartz.impl.jdbcjobstore.oracle.OracleDelegate` |
| Quartz table prefix | `QRTZ6_` |
| Hibernate config | `oracle10g.hibernate.cfg.xml` |
| Validation query | `SELECT 1 FROM DUAL` |

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

Oracle thin client format:
```
jdbc:oracle:thin:@//repository:1521/FREEPDB1
```

Alternative SID format:
```
jdbc:oracle:thin:@repository:1521:ORCL
```

## Oracle Architecture Notes

This configuration uses Oracle Free (23ai) with a Pluggable Database (PDB):
- **Container Database (CDB):** FREE
- **Pluggable Database (PDB):** FREEPDB1
- All Pentaho schemas are created within the same PDB
- Each user (hibuser, pentaho_user, jcr_user) has its own schema

## Customization

### Changing Database Passwords

1. Update SQL initialization scripts in `db_init_oracle/`
2. Update `context.xml` with new passwords
3. Recreate Oracle volume and restart:
   ```bash
   docker compose down -v
   docker compose up -d
   ```

### Using Different Service Name

If using a different Oracle service name:

1. Update all JDBC URLs in `context.xml`:
   ```
   jdbc:oracle:thin:@//repository:1521/YOUR_SERVICE_NAME
   ```
2. Update `repository.xml` and other config files accordingly

### Using Different Database

To use PostgreSQL instead of Oracle:

1. Add PostgreSQL driver to `1_drivers/tomcat/lib/`
2. Update `context.xml` with PostgreSQL JDBC URL
3. Update `repository.xml`, `quartz.properties`, `hibernate-settings.xml`
4. Create PostgreSQL initialization scripts

## Troubleshooting

### Connection Refused

```
IO Error: The Network Adapter could not establish the connection
```

**Cause:** Oracle not ready or incorrect hostname
**Solution:** Verify Oracle container is healthy: `docker compose ps`

### Invalid Service Name

```
ORA-12514: TNS:listener does not currently know of service requested
```

**Cause:** Service name mismatch
**Solution:** Verify service name is `FREEPDB1` and Oracle listener is running

### Login Failed

```
ORA-01017: invalid username/password; logon denied
```

**Cause:** Password mismatch between context.xml and database
**Solution:** Verify passwords match in `context.xml` and database init scripts

### Tablespace Issues

```
ORA-01653: unable to extend table
```

**Cause:** Insufficient tablespace
**Solution:** Extend the tablespace or configure auto-extend

### Quartz Errors

```
ORA-00942: table or view does not exist (QRTZ6_LOCKS)
```

**Cause:** Quartz tables not created
**Solution:** Verify `QRTZ6_*` tables exist in the pentaho_user schema

### Container Networking

**Cause:** Pentaho and Oracle not on the same Docker network
**Solution:** Ensure both containers are defined in the same `docker-compose.yml`

### Oracle Startup Time

**Note:** Oracle containers take longer to start than other databases. Wait for the healthcheck to pass before starting Pentaho.

## Related Documentation

- [Main README](../../README.md) - Project overview
- [softwareOverride README](../README.md) - Override system documentation
- [ARCHITECTURE.md](../../ARCHITECTURE.md) - Database schema details
