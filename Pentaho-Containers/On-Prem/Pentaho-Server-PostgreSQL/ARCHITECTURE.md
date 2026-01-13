# System Architecture

## Overview

This deployment uses Docker Compose to orchestrate Pentaho Server 11 with PostgreSQL 15.

```
┌─────────────────────────────────────────────────────────────┐
│                   Docker Host (Ubuntu 24.04)                │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │               pentaho-net (172.28.0.0/16)             │  │
│  │                                                       │  │
│  │  ┌─────────────────┐       ┌─────────────────┐       │  │
│  │  │   PostgreSQL    │       │     Pentaho     │       │  │
│  │  │       15        │◄──────│     Server      │       │  │
│  │  │                 │       │      11.0       │       │  │
│  │  │     :5432       │       │     :8080       │       │  │
│  │  └─────────────────┘       └─────────────────┘       │  │
│  │          │                         │                 │  │
│  └──────────┼─────────────────────────┼─────────────────┘  │
│             │                         │                    │
│       :5432 ▼                   :8090 ▼                    │
│     (optional)                    HTTP                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Components

### PostgreSQL 15

**Container:** `pentaho-postgres`
**Hostname:** `repository`
**Port:** 5432

Stores all Pentaho repository data:

| Database | Schema | Purpose |
|----------|--------|---------|
| jackrabbit | public | JCR content repository |
| quartz | public | Scheduler job store |
| hibernate | public | Pentaho metadata |
| hibernate | pentaho_dilogs | Execution logging |
| hibernate | pentaho_operations_mart | Analytics data mart |

### Pentaho Server 11

**Container:** `pentaho-server`
**Hostname:** `pentaho-server`
**Ports:** 8080 (internal), 8090 (external HTTP), 8443 (external HTTPS)

Components:
- Apache Tomcat 9 (servlet container)
- Pentaho BI Platform
- Jackrabbit JCR (content repository)
- Quartz Scheduler
- Mondrian OLAP Engine

## Volume Mapping

```
Docker Volumes:
├── pentaho_postgres_data  → /var/lib/postgresql/data
├── pentaho_solutions      → /opt/pentaho/pentaho-server/pentaho-solutions
└── pentaho_data           → /opt/pentaho/pentaho-server/data

Bind Mounts:
├── ./softwareOverride     → /docker-entrypoint-init (ro)
├── ./db_init_postgres     → /docker-entrypoint-initdb.d (ro)
├── ./postgres-config      → /etc/postgresql/conf.d (ro)
├── ./config/.kettle       → /home/pentaho/.kettle
└── ./config/.pentaho      → /home/pentaho/.pentaho
```

## Configuration Overlay System

The entrypoint script processes directories in order:

```
/docker-entrypoint-init/
├── 1_drivers/      # JDBC drivers
├── 2_repository/   # Database configuration (PostgreSQL)
├── 3_security/     # Authentication settings
└── 4_others/       # Tomcat, defaults
```

Files are copied to the Pentaho installation, overriding defaults.

## Database Schema

### Quartz Tables (QRTZ6_*)

```
quartz database
├── QRTZ6_JOB_DETAILS
├── QRTZ6_TRIGGERS
├── QRTZ6_SIMPLE_TRIGGERS
├── QRTZ6_CRON_TRIGGERS
├── QRTZ6_BLOB_TRIGGERS
├── QRTZ6_CALENDARS
├── QRTZ6_PAUSED_TRIGGER_GRPS
├── QRTZ6_FIRED_TRIGGERS
├── QRTZ6_SCHEDULER_STATE
└── QRTZ6_LOCKS
```

### Jackrabbit Tables

Created dynamically on first startup:
- `fs_repos_*` - Repository filesystem
- `fs_ws_*` - Workspace filesystem
- `ds_repos_*` - DataStore
- `pm_*` - Persistence manager
- `J_C_*` - Cluster journal

### Logging Schema (pentaho_dilogs)

```
hibernate.pentaho_dilogs
├── job_logs
├── jobentry_logs
├── trans_logs
├── step_logs
├── channel_logs
├── checkpoint_logs
├── metrics_logs
└── transperf_logs
```

### Operations Mart Schema

```
hibernate.pentaho_operations_mart
├── Dimensions: DIM_DATE, DIM_TIME, DIM_BATCH, etc.
├── Facts: FACT_EXECUTION, FACT_STEP_EXECUTION, etc.
└── Staging: STG_*, PRO_AUDIT_*
```

## Network Architecture

All containers communicate via Docker bridge network:

- Network: `pentaho-net`
- Subnet: `172.28.0.0/16`
- Internal hostname resolution via Docker DNS

## Health Checks

| Service | Check | Interval | Timeout |
|---------|-------|----------|---------|
| PostgreSQL | `pg_isready -U postgres` | 10s | 5s |
| Pentaho | `curl http://localhost:8080/pentaho/Login` | 30s | 10s |

## Startup Sequence

1. PostgreSQL starts and initializes databases
2. PostgreSQL health check passes
3. Pentaho Server starts (depends on PostgreSQL health)
4. Entrypoint copies configuration overlays
5. Tomcat starts Pentaho application
6. Jackrabbit initializes JCR tables (first run)
7. Pentaho ready (logs "Server startup in")

## Security Model

```
┌─────────────────────────────────────────┐
│            Spring Security              │
├─────────────────────────────────────────┤
│ Authentication Provider:                │
│ - Memory (default)                      │
│ - Hibernate (database-backed)           │
│ - LDAP                                  │
│ - SAML                                  │
├─────────────────────────────────────────┤
│ Authorization:                          │
│ - Role-based access control (RBAC)      │
│ - JCR ACLs for content                  │
└─────────────────────────────────────────┘
```
