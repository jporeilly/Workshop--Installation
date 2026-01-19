# 2_repository - Database Repository Configuration

## Purpose

This directory contains configuration files for Pentaho's internal repositories and database connections. It configures how Pentaho connects to and uses PostgreSQL for:

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
          url="jdbc:postgresql://repository:5432/hibernate"
          username="hibuser"
          password="password"/>

<Resource name="jdbc/Quartz"
          type="javax.sql.DataSource"
          url="jdbc:postgresql://repository:5432/quartz"
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
| `jdbc/live_logging_info` | hibernate | hibuser | Live logging (schema: pentaho_dilogs) |
| `jdbc/jackrabbit` | jackrabbit | jcr_user | JackRabbit content repository |
| `jdbc/SampleData` | sampledata | sa | Sample data (HSQLDB) |

## PostgreSQL-specific Settings

| Setting | Value |
|---------|-------|
| JDBC Driver | `org.postgresql.Driver` |
| Default Port | `5432` |
| Database Host | `repository` (container name) |
| Jackrabbit schema | `postgresql` |
| Quartz delegate | `org.quartz.impl.jdbcjobstore.PostgreSQLDelegate` |
| Quartz table prefix | `QRTZ6_` |
| Hibernate config | `postgresql.hibernate.cfg.xml` |
| Validation query | `select 1` |

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
jdbc:postgresql://repository:5432/<database>
```

## Customization

### Changing Database Passwords

1. Update SQL initialization scripts in `db_init_postgres/`
2. Update `context.xml` with new passwords
3. Recreate PostgreSQL volume and restart:
   ```bash
   docker compose down -v
   docker compose up -d
   ```

### Using Different Database

To use MySQL instead of PostgreSQL:

1. Add MySQL driver to `1_drivers/tomcat/lib/`
2. Update `context.xml` with MySQL JDBC URL
3. Update `repository.xml`, `quartz.properties`, `hibernate-settings.xml`
4. Create MySQL initialization scripts

## Troubleshooting

### Connection Refused

```
Communications link failure - Connection refused
```

**Cause:** PostgreSQL not ready or incorrect hostname
**Solution:** Verify PostgreSQL container is healthy: `docker compose ps`

### Unknown Database

```
FATAL: database "hibernate" does not exist
```

**Cause:** Database initialization scripts didn't run
**Solution:** Recreate PostgreSQL volume: `docker compose down -v && docker compose up -d`

### Access Denied

```
FATAL: password authentication failed for user "hibuser"
```

**Cause:** Password mismatch between context.xml and database
**Solution:** Verify passwords match in `context.xml` and database init scripts

### Quartz Errors

```
Table "QRTZ6_LOCKS" not found
```

**Cause:** Quartz tables not created
**Solution:** Verify `QRTZ6_*` tables exist in the `quartz` database

### Container Networking

**Cause:** Pentaho and PostgreSQL not on the same Docker network
**Solution:** Ensure both containers are defined in the same `docker-compose.yml`

## Related Documentation

- [Main README](../../README.md) - Project overview
- [softwareOverride README](../README.md) - Override system documentation
- [ARCHITECTURE.md](../../ARCHITECTURE.md) - Database schema details
