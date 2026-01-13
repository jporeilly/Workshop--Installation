# 2_repository - Database Repository Configuration

## Purpose

This directory contains configuration files for Pentaho's internal repositories and database connections. It configures how Pentaho connects to and uses MySQL for:

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
          url="jdbc:mysql://repository:3306/hibernate"
          username="hibuser"
          password="password"/>

<Resource name="jdbc/Quartz"
          type="javax.sql.DataSource"
          url="jdbc:mysql://repository:3306/quartz"
          username="quartz_user"
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

## Database Connection Details

| Database | JNDI Name | Default User | Default Password |
|----------|-----------|--------------|------------------|
| hibernate | jdbc/Hibernate | hibuser | password |
| quartz | jdbc/Quartz | quartz_user | password |
| jackrabbit | jdbc/jackrabbit | jcr_user | password |

**Host:** `repository` (MySQL container hostname)
**Port:** `3306`

## Customization

### Changing Database Passwords

1. Update SQL initialization scripts in `db_init_mysql/`
2. Update `context.xml` with new passwords
3. Recreate MySQL volume and restart:
   ```bash
   docker compose down -v
   docker compose up -d
   ```

### Using Different Database

To use PostgreSQL instead of MySQL:

1. Add PostgreSQL driver to `1_drivers/tomcat/lib/`
2. Update `context.xml` with PostgreSQL JDBC URL
3. Update `repository.xml`, `quartz.properties`, `hibernate-settings.xml`
4. Create PostgreSQL initialization scripts

## Troubleshooting

### Connection Refused

```
Communications link failure - Connection refused
```

**Cause:** MySQL not ready or incorrect hostname
**Solution:** Verify MySQL container is healthy: `docker compose ps mysql`

### Unknown Database

```
Unknown database 'hibernate'
```

**Cause:** Database initialization scripts didn't run
**Solution:** Recreate MySQL volume: `docker compose down -v && docker compose up -d mysql`

### Access Denied

```
Access denied for user 'hibuser'@'%'
```

**Cause:** Password mismatch between context.xml and database
**Solution:** Verify passwords match in `context.xml` and `db_init_mysql/*.sql`

## Related Documentation

- [Main README](../../README.md) - Project overview
- [softwareOverride README](../README.md) - Override system documentation
- [ARCHITECTURE.md](../../ARCHITECTURE.md) - Database schema details
