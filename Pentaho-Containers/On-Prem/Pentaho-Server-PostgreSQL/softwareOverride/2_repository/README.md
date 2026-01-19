# Repository Configuration (PostgreSQL)

This directory contains Pentaho Server repository configuration files for PostgreSQL database backend.

## Prerequisites

- PostgreSQL 12+ installed and running
- Three databases created: `hibernate`, `quartz`, `jackrabbit`
- Database users created with appropriate permissions

## Files

| File | Purpose |
|------|---------|
| `tomcat/webapps/pentaho/META-INF/context.xml` | JDBC datasource definitions |
| `pentaho-solutions/system/jackrabbit/repository.xml` | JackRabbit repository configuration |
| `pentaho-solutions/system/hibernate/hibernate-settings.xml` | Hibernate database settings |
| `pentaho-solutions/system/repository.spring.properties` | Repository Spring configuration |
| `pentaho-solutions/system/scheduler-plugin/quartz/quartz.properties` | Quartz scheduler configuration |
| `pentaho-solutions/system/audit_sql.xml` | Audit SQL configuration |

## PostgreSQL-specific Settings

| Setting | Value |
|---------|-------|
| JDBC Driver | `org.postgresql.Driver` |
| Default Port | `5432` |
| Jackrabbit schema | `postgresql` |
| Quartz delegate | `org.quartz.impl.jdbcjobstore.PostgreSQLDelegate` |
| Hibernate config | `postgresql.hibernate.cfg.xml` |

## Database Users

| User | Database | Purpose |
|------|----------|---------|
| hibuser | hibernate | Hibernate repository, audit, operations mart |
| pentaho_user | quartz | Quartz scheduler |
| jcr_user | jackrabbit | JackRabbit content repository |

## Connection String Format

```
jdbc:postgresql://<host>:5432/<database>
```

## Security Note

Default credentials should be changed in production environments. Update passwords in `context.xml` and ensure they match your PostgreSQL user configurations.

## Troubleshooting

- **Connection refused**: Verify PostgreSQL is running and accepting connections on port 5432
- **Authentication failed**: Check username/password in `context.xml`
- **Database does not exist**: Ensure all three databases are created before starting Pentaho
