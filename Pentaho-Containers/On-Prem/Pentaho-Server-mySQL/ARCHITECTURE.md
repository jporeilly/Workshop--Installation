# Architecture Documentation

## System Overview

This document describes the architecture of the Pentaho Server 11 Docker deployment with MySQL repository on Ubuntu 24.04.

## High-Level Architecture

```
                              ┌─────────────────────────────────────────────────────────┐
                              │                  Docker Host (Ubuntu 24.04)             │
                              │                                                         │
    HTTP :8090  ─────────────►│  ┌─────────────────────────────────────────────────┐   │
    HTTPS :8443 ─────────────►│  │           pentaho-server container              │   │
                              │  │                                                 │   │
                              │  │  ┌───────────────────────────────────────────┐ │   │
                              │  │  │  Pentaho Server 11.0.0.0-237              │ │   │
                              │  │  │  - Business Analytics Platform            │ │   │
                              │  │  │  - Report Designer                        │ │   │
                              │  │  │  - Data Integration                       │ │   │
                              │  │  └───────────────────────────────────────────┘ │   │
                              │  │                                                 │   │
                              │  │  ┌───────────────────────────────────────────┐ │   │
                              │  │  │  Apache Tomcat 9                          │ │   │
                              │  │  │  - Servlet Container                      │ │   │
                              │  │  │  - JNDI DataSources                       │ │   │
                              │  │  └───────────────────────────────────────────┘ │   │
                              │  │                                                 │   │
                              │  │  ┌───────────────────────────────────────────┐ │   │
                              │  │  │  OpenJDK 21 JRE                           │ │   │
                              │  │  │  - Debian Trixie Slim base                │ │   │
                              │  │  └───────────────────────────────────────────┘ │   │
                              │  └────────────────────────┬────────────────────────┘   │
                              │                           │                            │
                              │                           │ JDBC (mysql-connector-j)   │
                              │                           ▼                            │
                              │  ┌─────────────────────────────────────────────────┐   │
    MySQL :3306 ─────────────►│  │           pentaho-mysql container               │   │
                              │  │                                                 │   │
                              │  │  ┌─────────────────────────────────────────┐   │   │
                              │  │  │  MySQL 8.0                              │   │   │
                              │  │  │                                         │   │   │
                              │  │  │  Databases:                             │   │   │
                              │  │  │  ├── jackrabbit (JCR content)           │   │   │
                              │  │  │  ├── quartz (job scheduler)             │   │   │
                              │  │  │  ├── hibernate (repository)             │   │   │
                              │  │  │  ├── pentaho_logging (audit)            │   │   │
                              │  │  │  └── pentaho_mart (operations)          │   │   │
                              │  │  └─────────────────────────────────────────┘   │   │
                              │  └─────────────────────────────────────────────────┘   │
                              │                                                         │
                              │                    pentaho-net                          │
                              │                  (172.28.0.0/16)                        │
                              └─────────────────────────────────────────────────────────┘
```

## Container Architecture

### pentaho-server Container

**Base Image:** `debian:trixie-slim`

**Build Process:** Multi-stage Docker build

```
Stage 1: install_unpack
├── Extract pentaho-server-ee-11.0.0.0-237.zip
├── Install optional plugins (PAZ, PIR, PDD if present)
└── Remove default content for non-demo mode

Stage 2: pack (final image)
├── Install OpenJDK 21 JRE
├── Create pentaho user (UID 5000)
├── Copy Pentaho installation from Stage 1
├── Copy entrypoint scripts
└── Set working directory and entrypoint
```

**Key Directories:**
| Path | Purpose |
|------|---------|
| `/opt/pentaho/pentaho-server` | Pentaho installation root |
| `/opt/pentaho/pentaho-server/tomcat` | Tomcat server |
| `/opt/pentaho/pentaho-server/pentaho-solutions` | Solutions repository |
| `/opt/pentaho/pentaho-server/data` | Data files |
| `/home/pentaho` | Pentaho user home |

**Exposed Ports:**
- `8080` - HTTP (mapped to host 8090)
- `8443` - HTTPS

**User:** `pentaho` (UID 5000, GID 5000)

### pentaho-mysql Container

**Image:** `mysql:8.0`

**Hostname:** `repository` (for JDBC connections)

**Databases Created:**
| Database | Purpose | User |
|----------|---------|------|
| jackrabbit | JCR content repository | jcr_user |
| quartz | Job scheduler | quartz_user |
| hibernate | Pentaho repository | hibernate_user |
| pentaho_logging | Audit logging | pentaho_user |
| pentaho_mart | Operations mart | pentaho_user |

**Configuration:** Custom `mysql-config/custom.cnf` with:
- UTF-8 MB4 character set
- 200 max connections
- 512MB InnoDB buffer pool
- Binary logging enabled
- Slow query logging enabled

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       pentaho-net                               │
│                     Bridge Network                              │
│                    172.28.0.0/16                                │
│                                                                 │
│   ┌─────────────────┐   ┌─────────────────┐                    │
│   │ pentaho-server  │   │ pentaho-mysql   │                    │
│   │   (dynamic IP)  │   │   (dynamic IP)  │                    │
│   │                 │   │                 │                    │
│   │ hostname:       │   │ hostname:       │                    │
│   │ pentaho-server  │   │ repository      │                    │
│   └─────────────────┘   └─────────────────┘                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key Features:**
- Custom subnet (172.28.0.0/16) avoids VPN conflicts
- Service discovery via container hostnames
- Network isolation from host
- Inter-container communication on internal network

## Volume Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       Named Volumes                             │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  pentaho_mysql_data                                      │   │
│  │  └── MySQL data files (/var/lib/mysql)                   │   │
│  │      Persists all database content                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  pentaho_solutions                                       │   │
│  │  └── Pentaho solutions (/opt/pentaho/.../pentaho-solutions)│ │
│  │      Persists reports, dashboards, transformations       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  pentaho_data                                            │   │
│  │  └── Pentaho data files (/opt/pentaho/.../data)          │   │
│  │      Persists HSQLDB sample data                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       Bind Mounts                               │
│                                                                 │
│  ./db_init_mysql      → /docker-entrypoint-initdb.d (MySQL)    │
│  ./mysql-config       → /etc/mysql/conf.d (MySQL)              │
│  ./softwareOverride   → /docker-entrypoint-init (Pentaho)      │
│  ./config/.kettle     → /home/pentaho/.kettle (Pentaho)        │
│  ./config/.pentaho    → /home/pentaho/.pentaho (Pentaho)       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Startup Sequence

```
┌──────────────────────────────────────────────────────────────────┐
│                      Startup Flow                                │
└──────────────────────────────────────────────────────────────────┘

1. docker compose up -d
   │
   ├─► Start pentaho-mysql container
   │   │
   │   ├─► Initialize MySQL 8.0
   │   ├─► Execute db_init_mysql/*.sql scripts (alphabetically)
   │   │   ├─► 1_create_jcr_mysql.sql      → jackrabbit database
   │   │   ├─► 2_create_quartz_mysql.sql   → quartz database
   │   │   ├─► 3_create_repository_mysql.sql → hibernate database
   │   │   ├─► 4_pentaho_logging_mysql.sql → logging tables
   │   │   └─► 5_pentaho_mart_mysql.sql    → operations mart
   │   │
   │   └─► Health check: mysqladmin ping
   │
   ├─► Wait for MySQL healthy
   │
   ├─► Start pentaho-server container
   │   │
   │   ├─► Execute docker-entrypoint.sh
   │   │   ├─► Set CATALINA_OPTS (JVM memory, encoding)
   │   │   ├─► Process softwareOverride directories
   │   │   │   ├─► 1_drivers/    → Copy JDBC drivers
   │   │   │   ├─► 2_repository/ → Copy repository config
   │   │   │   ├─► 3_security/   → Copy security config
   │   │   │   └─► 4_others/     → Copy other config
   │   │   └─► Optional: Install license if LICENSE_URL set
   │   │
   │   ├─► Execute start-pentaho.sh
   │   │   └─► Start Tomcat with Pentaho webapp
   │   │
   │   └─► Health check: HTTP GET /pentaho/

2. Deployment Complete
   │
   ├─► Pentaho Server: http://localhost:8090/pentaho
   └─► MySQL: localhost:3306
```

## Software Override Processing Flow

```
Container Startup
       │
       ▼
┌─────────────────────────────────────┐
│  docker-entrypoint.sh               │
│                                     │
│  for dir in /docker-entrypoint-init/*; do
│      if [ ! -f "$dir/.ignore" ]; then
│          cp -a "$dir/." "$PENTAHO_SERVER_PATH"
│      fi
│  done
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│  Processing Order (alphabetical)    │
│                                     │
│  1_drivers/                         │
│  ├── tomcat/lib/mysql-connector-j   │──► /opt/pentaho/pentaho-server/tomcat/lib/
│  └── pentaho-solutions/drivers/     │──► /opt/pentaho/pentaho-server/pentaho-solutions/drivers/
│                                     │
│  2_repository/                      │
│  ├── pentaho-solutions/system/      │──► /opt/pentaho/pentaho-server/pentaho-solutions/system/
│  └── tomcat/webapps/.../context.xml │──► /opt/pentaho/pentaho-server/tomcat/webapps/.../
│                                     │
│  3_security/                        │
│  └── pentaho-solutions/system/      │──► /opt/pentaho/pentaho-server/pentaho-solutions/system/
│                                     │
│  4_others/                          │
│  ├── pentaho-solutions/system/      │──► /opt/pentaho/pentaho-server/pentaho-solutions/system/
│  └── tomcat/...                     │──► /opt/pentaho/pentaho-server/tomcat/...
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│  Start Pentaho Server               │
│  (with applied configurations)      │
└─────────────────────────────────────┘
```

## Database Schema Overview

### jackrabbit Database (JCR Content Repository)

Stores all content managed by Pentaho:
- Reports and analyses
- Dashboards
- Data sources
- Schedules metadata
- User preferences

Key Tables:
- `PM_NODE` - Repository nodes
- `PM_BUNDLE` - Binary content
- `PM_REFS` - Node references

### quartz Database (Job Scheduler)

Stores scheduled job information:
- Job definitions
- Triggers and schedules
- Execution history

Key Tables:
- `QRTZ_JOB_DETAILS` - Job definitions
- `QRTZ_TRIGGERS` - Trigger configurations
- `QRTZ_CRON_TRIGGERS` - Cron expressions
- `QRTZ_FIRED_TRIGGERS` - Execution history

### hibernate Database (Pentaho Repository)

Stores Pentaho-specific metadata:
- User and role information
- Permissions
- Repository configuration

Key Tables:
- `USERS` - User accounts
- `ROLES` - Role definitions
- `PERMISSIONS` - Access control

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Security Layers                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Network Security                                            │
│     └── pentaho-net bridge network (isolated)                   │
│                                                                 │
│  2. Container Security                                          │
│     └── Non-root user (pentaho, UID 5000)                       │
│                                                                 │
│  3. Application Security                                        │
│     ├── Spring Security framework                               │
│     ├── Authentication (memory/hibernate/LDAP/OAuth)            │
│     └── Role-based access control                               │
│                                                                 │
│  4. Database Security                                           │
│     ├── Separate users per database                             │
│     └── Password authentication                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Performance Considerations

### JVM Memory Settings

| Setting | Default | Recommended (16GB host) |
|---------|---------|------------------------|
| PENTAHO_MIN_MEMORY | 2048m | 4096m |
| PENTAHO_MAX_MEMORY | 4096m | 8192m |

### MySQL Tuning

Key settings in `mysql-config/custom.cnf`:
- `innodb_buffer_pool_size=512M` - Increase for larger datasets
- `max_connections=200` - Adjust based on concurrent users
- `slow_query_log=1` - Enable for performance analysis

### Docker Resource Limits

Consider adding to `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
```

## Related Documentation

- [README.md](README.md) - Quick start and overview
- [CONFIGURATION.md](CONFIGURATION.md) - Configuration reference
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Problem solving
- [softwareOverride/README.md](softwareOverride/README.md) - Override system
