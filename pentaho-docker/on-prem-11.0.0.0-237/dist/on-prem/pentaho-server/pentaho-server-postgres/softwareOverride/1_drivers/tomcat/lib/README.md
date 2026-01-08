# PostgreSQL JDBC Driver

Place the PostgreSQL JDBC driver JAR file in this folder.

## Required Driver

Download the PostgreSQL JDBC driver from:
- https://jdbc.postgresql.org/download/

**Recommended version for PostgreSQL 17:** `postgresql-42.7.8.jar` or later

## Download Command

```bash
curl -L -o postgresql-42.7.8.jar https://jdbc.postgresql.org/download/postgresql-42.7.8.jar
```

## Notes

- The driver will be copied to `$TOMCAT_HOME/lib` during container initialization
- This driver is required for Pentaho to connect to the PostgreSQL repository
- Ensure the JAR file is placed in this folder before building the Docker image
