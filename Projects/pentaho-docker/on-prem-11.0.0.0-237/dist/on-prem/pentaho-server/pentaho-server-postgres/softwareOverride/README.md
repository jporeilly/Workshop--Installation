# Software Override Directory

This folder contains sub-folders that the Docker entrypoint copies into the Pentaho installation in **alphabetical order**.

## Directory Structure

| Folder | Purpose |
|--------|---------|
| `1_drivers/` | JDBC drivers (PostgreSQL, etc.) |
| `2_repository/` | Repository configuration (Hibernate, Quartz, Jackrabbit, context.xml) |
| `3_security/` | Security configuration files |
| `4_others/` | Additional configuration overrides |
| `99_exchange/` | Exchange/import files |

## How It Works

During container startup, the entrypoint script processes each folder alphabetically and copies:
- `pentaho-solutions/*` → `$PENTAHO_SERVER/pentaho-solutions/`
- `tomcat/*` → `$PENTAHO_SERVER/tomcat/`

This allows configuration changes without modifying the base Pentaho image.
