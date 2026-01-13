# Software Override Directory

## Overview

This directory contains configuration overrides that customize the Pentaho Server installation without modifying the core distribution. Files are copied into the Pentaho installation directory during container startup, processed in alphabetical order by directory name.

## How It Works

When the Pentaho Server container starts, the entrypoint script (`docker/entrypoint/docker-entrypoint.sh`) processes each subdirectory in alphabetical order:

1. Reads directories sorted alphabetically (1_, 2_, 3_, 4_, etc.)
2. Skips directories containing a `.ignore` file
3. Copies all contents recursively into `/opt/pentaho/pentaho-server/`
4. Preserves directory structure and file permissions

This allows you to overlay custom configurations on top of the base Pentaho installation.

## Directory Structure

```
softwareOverride/
├── README.md              # This file
├── 1_drivers/             # JDBC drivers and data connectors (processed FIRST)
├── 2_repository/          # Database and persistence configuration
├── 3_security/            # Authentication and authorization
├── 4_others/              # Tomcat, defaults, and miscellaneous
└── 99_exchange/           # User data exchange (not auto-processed)
```

## Directory Details

### 1_drivers/ - JDBC Drivers and Connectors

**Purpose:** Database drivers and data source connectors required for Pentaho to connect to external databases.

**Current Contents:**
```
1_drivers/
├── tomcat/lib/
│   └── mysql-connector-j-8.3.0.jar    # MySQL 8.x JDBC driver (REQUIRED)
└── pentaho-solutions/drivers/
    └── README                          # Big data driver instructions
```

**Key Files:**
- `mysql-connector-j-8.3.0.jar` - Required for Pentaho to connect to the MySQL repository
- Big data drivers (.kar files) go in `pentaho-solutions/drivers/`

**Adding JDBC Drivers:**
```bash
# Example: Add PostgreSQL driver
cp postgresql-42.7.1.jar 1_drivers/tomcat/lib/

# Example: Add Oracle driver
cp ojdbc11.jar 1_drivers/tomcat/lib/
```

### 2_repository/ - Repository Configuration

**Purpose:** Database connection settings for Pentaho's internal repositories (JackRabbit, Quartz, Hibernate).

**Current Contents:**
```
2_repository/
├── pentaho-solutions/system/
│   ├── audit_sql.xml                   # Audit logging SQL
│   ├── hibernate/
│   │   └── hibernate-settings.xml      # Hibernate ORM settings
│   ├── jackrabbit/
│   │   └── repository.xml              # JCR repository configuration
│   ├── repository.spring.properties    # Repository Spring settings
│   └── scheduler-plugin/quartz/
│       └── quartz.properties           # Job scheduler configuration
└── tomcat/webapps/pentaho/META-INF/
    └── context.xml                     # JNDI datasource definitions
```

**Key Configurations:**
- `context.xml` - Defines JNDI datasources for jackrabbit, quartz, and hibernate databases
- `repository.xml` - JackRabbit content repository settings
- `quartz.properties` - Scheduler database connection

### 3_security/ - Security Configuration

**Purpose:** Authentication and authorization settings for Pentaho Server.

**Current Contents:**
```
3_security/
└── pentaho-solutions/system/
    ├── applicationContext-spring-security-hibernate.properties
    └── applicationContext-spring-security-memory.xml
```

**Authentication Options:**
- **Memory-based** (default for development) - Users defined in XML
- **Hibernate-based** - Users stored in database
- **LDAP** - External directory service
- **OAuth/SAML** - Single sign-on

### 4_others/ - Additional Configuration

**Purpose:** Tomcat configuration, default users, sample data, and miscellaneous settings.

**Current Contents:**
```
4_others/
├── pentaho-solutions/system/
│   ├── applicationContext-spring-security-oauth.properties
│   ├── defaultUser.spring.properties
│   ├── defaultUser.spring.xml
│   ├── pentaho.xml
│   └── security.properties
├── tomcat/
│   ├── bin/startup.sh
│   └── webapps/pentaho/WEB-INF/web.xml
└── data/hsqldb/
    ├── sampledata.properties
    └── sampledata.script
```

### 99_exchange/ - User Data Exchange

**Purpose:** Directory for user data that should persist but not be auto-processed during startup.

**Usage:**
- Place files here that you want accessible inside the container
- Files are NOT automatically copied to Pentaho installation
- Useful for manual data import/export

## Processing Order

The alphabetical naming ensures consistent processing order:

| Order | Directory | What It Configures |
|-------|-----------|-------------------|
| 1st | 1_drivers | JDBC drivers loaded before any DB connections |
| 2nd | 2_repository | Database connections configured |
| 3rd | 3_security | Authentication mechanisms applied |
| 4th | 4_others | Application settings finalized |
| Skip | 99_exchange | Not auto-processed (user data only) |

## Adding Custom Configurations

### Step-by-Step Guide

1. **Identify the target file path** in the Pentaho installation:
   ```
   /opt/pentaho/pentaho-server/path/to/file.xml
   ```

2. **Create matching structure** under softwareOverride:
   ```bash
   mkdir -p softwareOverride/4_others/path/to/
   ```

3. **Place your customized file**:
   ```bash
   cp your-custom-file.xml softwareOverride/4_others/path/to/file.xml
   ```

4. **Rebuild and restart**:
   ```bash
   docker compose build --no-cache pentaho-server
   docker compose up -d pentaho-server
   ```

### Example: Custom Logging Configuration

```bash
# Create directory structure
mkdir -p softwareOverride/4_others/tomcat/webapps/pentaho/WEB-INF/classes/

# Copy custom log4j2 configuration
cp my-log4j2.xml softwareOverride/4_others/tomcat/webapps/pentaho/WEB-INF/classes/log4j2.xml

# Rebuild container
docker compose build --no-cache pentaho-server
```

## Skipping Directories

To prevent a directory from being processed:

```bash
# Create .ignore file
touch softwareOverride/3_security/.ignore
```

The entrypoint script will skip any directory containing a `.ignore` file.

## Best Practices

1. **Use appropriate directory**: Place files in the correct numbered directory based on their purpose
2. **Preserve structure**: Mirror the exact path structure from Pentaho installation
3. **Test changes**: Always test in development before applying to production
4. **Document changes**: Comment your configuration files explaining customizations
5. **Backup originals**: Keep copies of original files before overriding
6. **Version control**: Track all override files in git (except sensitive data)

## Troubleshooting

### Files Not Being Applied

1. Check directory naming (must be alphabetically sortable)
2. Verify no `.ignore` file exists
3. Confirm file paths match Pentaho installation structure
4. Check entrypoint logs: `docker compose logs pentaho-server | grep -i override`

### Permission Issues

Files are copied with the `pentaho` user (UID 5000). Ensure:
- Files are readable by UID 5000
- No restrictive permissions on host

### Verifying Applied Changes

```bash
# Access container shell
docker compose exec pentaho-server bash

# Check if file was copied
ls -la /opt/pentaho/pentaho-server/path/to/your/file.xml

# View file contents
cat /opt/pentaho/pentaho-server/path/to/your/file.xml
```

## Related Documentation

- [Main README](../README.md) - Project overview and quick start
- [CONFIGURATION.md](../CONFIGURATION.md) - Detailed configuration reference
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture documentation
