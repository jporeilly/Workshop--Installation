# 1_drivers - JDBC Drivers and Data Connectors

## Purpose

This directory contains JDBC drivers and data source connectors that Pentaho needs to connect to external databases and data sources.

## Processing Order

This directory is processed **first** during container startup, ensuring drivers are available before any database connections are configured.

## Directory Structure

```
1_drivers/
├── README.md                          # This file
├── tomcat/
│   └── lib/
│       └── mysql-connector-j-8.3.0.jar   # MySQL JDBC driver (REQUIRED)
└── pentaho-solutions/
    └── drivers/
        └── README                     # Big data driver instructions
```

## Included Drivers

### MySQL Connector/J 8.3.0

**Location:** `tomcat/lib/mysql-connector-j-8.3.0.jar`

**Purpose:** Required for Pentaho to connect to the MySQL repository databases (jackrabbit, quartz, hibernate).

**Compatibility:** MySQL 8.0.x, MySQL 5.7.x

**Note:** The deprecation warning about `com.mysql.jdbc.Driver` is harmless. The driver automatically registers via SPI.

## Adding JDBC Drivers

### Standard JDBC Drivers

Place JAR files in `tomcat/lib/`:

```bash
# PostgreSQL
cp postgresql-42.7.1.jar tomcat/lib/

# Oracle
cp ojdbc11.jar tomcat/lib/

# SQL Server
cp mssql-jdbc-12.4.2.jre11.jar tomcat/lib/

# MariaDB
cp mariadb-java-client-3.3.2.jar tomcat/lib/
```

### Big Data Drivers

For Hadoop, Spark, and other big data drivers, place `.kar` files in `pentaho-solutions/drivers/`:

1. Download from Pentaho Support Portal
2. Run the installer to generate .kar file
3. Place in `pentaho-solutions/drivers/`

## Upgrading MySQL Driver

1. Download new version from [Maven Central](https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/)
2. Remove old driver:
   ```bash
   rm tomcat/lib/mysql-connector-j-*.jar
   ```
3. Add new driver:
   ```bash
   cp mysql-connector-j-X.X.X.jar tomcat/lib/
   ```
4. Rebuild container:
   ```bash
   docker compose build --no-cache pentaho-server
   docker compose up -d pentaho-server
   ```

## Troubleshooting

### Driver Not Found

```
Unable to load class: com.mysql.jdbc.Driver
```

**Solution:** Ensure driver JAR is in `tomcat/lib/` and rebuild container.

### Version Mismatch

If you encounter compatibility issues, ensure the driver version matches your database version:
- MySQL 8.0+ → mysql-connector-j-8.x
- MySQL 5.7 → mysql-connector-j-8.x (backward compatible)
- MySQL 5.6 → mysql-connector-java-5.x

## Related Documentation

- [Main README](../../README.md) - Project overview
- [softwareOverride README](../README.md) - Override system documentation
- [CONFIGURATION.md](../../CONFIGURATION.md) - Configuration reference
