# 1_drivers - JDBC Drivers Directory

## Table of Contents

- [Purpose](#purpose)
- [Microsoft SQL Server JDBC Driver](#microsoft-sql-server-jdbc-driver)
- [Direct Download Link](#direct-download-link)
- [Verification](#verification)
- [Important Notes](#important-notes)
- [Version Compatibility](#version-compatibility)
- [Related Documentation](#related-documentation)

## Purpose

This directory contains JDBC drivers required for Pentaho Server to connect to databases. Files placed here are copied to Tomcat's lib directory during container build.

## Processing Order

This directory is processed **first** during container startup, ensuring JDBC drivers are available before database connections are established.

## Microsoft SQL Server JDBC Driver

**Required for SQL Server repository connection**

### Download Instructions

1. Download the Microsoft JDBC Driver for SQL Server from:
   https://learn.microsoft.com/en-us/sql/connect/jdbc/download-microsoft-jdbc-driver-for-sql-server

2. Download version **12.x or later** (recommended: mssql-jdbc-12.8.1.jre11.jar)

3. Extract the downloaded archive and locate the JAR file:
   - For Java 11+: `mssql-jdbc-12.8.1.jre11.jar`
   - For Java 8: `mssql-jdbc-12.8.1.jre8.jar`

4. Copy the JAR file to this location:
   ```
   softwareOverride/1_drivers/tomcat/lib/mssql-jdbc-12.8.1.jre11.jar
   ```

## Direct Download Link

```bash
# Download using wget
cd softwareOverride/1_drivers/tomcat/lib/
wget https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.8.1.jre11/mssql-jdbc-12.8.1.jre11.jar
```

**Alternative:** You can also download from [Maven Central](https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/).

## Verification

After placing the driver, verify the file structure:
```
softwareOverride/1_drivers/
└── tomcat/
    └── lib/
        └── mssql-jdbc-12.8.1.jre11.jar  ← JDBC driver must be here
```

## Important Notes

- The driver is **required** before building the Docker image
- Without this driver, Pentaho Server cannot connect to SQL Server
- The driver will be automatically copied to Tomcat's lib directory during container build
- Driver version must be compatible with SQL Server 2022

## Version Compatibility

| SQL Server Version | Recommended Driver Version |
|--------------------|---------------------------|
| SQL Server 2022    | 12.x or later            |
| SQL Server 2019    | 9.x or later             |
| SQL Server 2017    | 7.x or later             |
| SQL Server 2016    | 6.x or later             |

For this deployment (SQL Server 2022), use driver version 12.x or later.

## Related Documentation

- [README.md](../../README.md) - Main project documentation
- [QUICKSTART.md](../../QUICKSTART.md) - Quick start guide
- [CONFIGURATION.md](../../CONFIGURATION.md) - Configuration reference
- [3_security/README.md](../3_security/README.md) - Security configuration
- [4_others/README.md](../4_others/README.md) - Additional configuration
