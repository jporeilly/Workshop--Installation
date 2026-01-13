# Software Override System

This directory contains configuration files that are overlaid onto the Pentaho Server installation at container startup.

## Directory Structure

```
softwareOverride/
├── 1_drivers/              # JDBC drivers (processed FIRST)
│   └── tomcat/lib/
│       └── ojdbc11.jar     # Oracle JDBC driver (REQUIRED)
│
├── 2_repository/           # Database repository configuration
│   ├── tomcat/webapps/pentaho/META-INF/
│   │   └── context.xml     # JNDI DataSource definitions
│   └── pentaho-solutions/system/
│       ├── hibernate/
│       │   └── hibernate-settings.xml
│       ├── jackrabbit/
│       │   └── repository.xml
│       └── scheduler-plugin/quartz/
│           └── quartz.properties
│
├── 3_security/             # Authentication settings
│
├── 4_others/               # Tomcat & miscellaneous config
│
└── 99_exchange/            # User data exchange (not auto-processed)
```

## Processing Order

Directories are processed in **alphabetical order** during container startup:
1. `1_drivers/` - JDBC drivers loaded first
2. `2_repository/` - Database configuration applied
3. `3_security/` - Security settings applied
4. `4_others/` - Additional configuration applied

The `99_exchange/` directory is **not automatically processed** - use it for data exchange between host and container.

## Required: Oracle JDBC Driver

You **must** download and place the Oracle JDBC driver in:
```
softwareOverride/1_drivers/tomcat/lib/ojdbc11.jar
```

Download from: https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html

Choose `ojdbc11.jar` (for Java 11+) from the Oracle Database 23c or 21c JDBC driver download.

## Disabling a Configuration

To temporarily disable a configuration directory, create a `.ignore` file in it:
```bash
touch softwareOverride/3_security/.ignore
```

## Adding Custom Configuration

1. Mirror the Pentaho Server directory structure
2. Place files in the appropriate numbered directory
3. Files will be copied to `$PENTAHO_SERVER_PATH` at startup

Example: To customize `web.xml`:
```
softwareOverride/4_others/tomcat/webapps/pentaho/WEB-INF/web.xml
```
