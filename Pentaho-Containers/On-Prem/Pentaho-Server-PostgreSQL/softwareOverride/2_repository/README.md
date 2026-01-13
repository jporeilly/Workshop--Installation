# Repository Configuration (PostgreSQL)

This directory contains Pentaho Server repository configuration files for PostgreSQL database backend.

## Files

- `tomcat/webapps/pentaho/META-INF/context.xml` - JDBC datasource definitions
- `pentaho-solutions/system/jackrabbit/repository.xml` - JackRabbit repository configuration
- `pentaho-solutions/system/hibernate/hibernate-settings.xml` - Hibernate database settings
- `pentaho-solutions/system/repository.spring.properties` - Repository Spring configuration
- `pentaho-solutions/system/scheduler-plugin/quartz/quartz.properties` - Quartz scheduler configuration
- `pentaho-solutions/system/audit_sql.xml` - Audit SQL configuration

## PostgreSQL-specific Settings

- JDBC Driver: `org.postgresql.Driver`
- Default Port: 5432
- Jackrabbit schema: `postgresql`
- Quartz delegate: `org.quartz.impl.jdbcjobstore.PostgreSQLDelegate`
- Hibernate config: `postgresql.hibernate.cfg.xml`

## Database Users

| User | Database | Purpose |
|------|----------|---------|
| hibuser | hibernate | Hibernate repository, audit, operations mart |
| pentaho_user | quartz | Quartz scheduler |
| jcr_user | jackrabbit | JackRabbit content repository |
