# Workshop: Deploying Pentaho Server 11 Containers

A hands-on workshop for deploying Pentaho Server 11 Enterprise Edition with MySQL repository using Docker containers on Ubuntu.

**Duration:** 2-3 hours
**Level:** Intermediate
**Prerequisites:** Basic Docker and Linux command line experience

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Prerequisites](#2-prerequisites)
3. [Understanding the Architecture](#3-understanding-the-architecture)
4. [Project Structure Walkthrough](#4-project-structure-walkthrough)
5. [Step-by-Step Deployment](#5-step-by-step-deployment)
6. [Configuration Deep-Dive](#6-configuration-deep-dive)
7. [Common Issues & Solutions](#7-common-issues--solutions)
8. [Production Considerations](#8-production-considerations)
9. [Hands-On Exercises](#9-hands-on-exercises)
10. [Appendix](#10-appendix)

---

## 1. Introduction

### Workshop Objectives

By the end of this workshop, you will be able to:

- Deploy a fully functional Pentaho Server 11 with MySQL repository
- Understand the Docker-based deployment architecture
- Configure Pentaho using the softwareOverride system
- Troubleshoot common deployment issues
- Implement production-ready configurations

### What is Pentaho Server?

Pentaho Server is an enterprise business analytics platform that provides:
- **Report Designer** - Create and schedule reports
- **Dashboard Designer** - Build interactive dashboards
- **Data Integration** - ETL processes via Pentaho Data Integration (PDI)
- **Analysis** - OLAP analytics via Mondrian
- **Scheduling** - Automated job execution via Quartz

### Why Docker?

Docker-based deployment offers several advantages:
- **Reproducibility** - Identical environments across dev/staging/production
- **Isolation** - No conflicts with host system dependencies
- **Portability** - Deploy anywhere Docker runs
- **Version Control** - Infrastructure as code
- **Easy Upgrades** - Rebuild containers with new versions

---

## 2. Prerequisites

### Required Software

| Software | Minimum Version | Check Command |
|----------|-----------------|---------------|
| Docker | 24.0+ | `docker --version` |
| Docker Compose | 2.20+ | `docker compose version` |
| Ubuntu | 22.04 or 24.04 | `cat /etc/os-release` |
| RAM | 8 GB minimum | `free -h` |
| Disk | 20 GB free | `df -h` |

### Installing Docker on Ubuntu

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group (logout/login required)
sudo usermod -aG docker $USER
```

### Obtaining Pentaho Server

1. Download Pentaho Server 11 Enterprise Edition from the Hitachi Vantara Software Portal
2. The file should be named: `pentaho-server-ee-11.0.0.0-237.zip`
3. Place the ZIP file in the `docker/stagedArtifacts/` directory

---

## 3. Understanding the Architecture

### Container Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Docker Host (Ubuntu)                            │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    pentaho-net (172.28.0.0/16)                   │   │
│  │                                                                   │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │   │
│  │  │ pentaho-server  │  │  pentaho-mysql  │  │ pentaho-adminer │  │   │
│  │  │                 │  │                 │  │                 │  │   │
│  │  │  Tomcat 9.x     │  │   MySQL 8.0     │  │    Adminer      │  │   │
│  │  │  OpenJDK 21     │  │                 │  │  (DB Admin UI)  │  │   │
│  │  │  Pentaho 11.0   │  │   Repository    │  │                 │  │   │
│  │  │                 │  │   Databases     │  │                 │  │   │
│  │  │  Port: 8080     │  │                 │  │                 │  │   │
│  │  │  (→ 8090)       │  │  Port: 3306     │  │  Port: 8080     │  │   │
│  │  │                 │  │                 │  │  (→ 8050)       │  │   │
│  │  └────────┬────────┘  └────────┬────────┘  └─────────────────┘  │   │
│  │           │                    │                                 │   │
│  │           │    JDBC/MySQL      │                                 │   │
│  │           └────────────────────┘                                 │   │
│  │                                                                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Exposed Ports:                                                         │
│  • 8090 → Pentaho Web UI                                               │
│  • 8443 → Pentaho HTTPS                                                │
│  • 3306 → MySQL (optional)                                             │
│  • 8050 → Adminer (optional)                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

### MySQL Repository Databases

Pentaho Server uses five MySQL databases:

| Database | Purpose | Key Tables |
|----------|---------|------------|
| `jackrabbit` | JCR content repository | Reports, dashboards, data sources |
| `quartz` | Job scheduler | QRTZ_* tables for scheduled jobs |
| `hibernate` | Pentaho metadata | Users, roles, permissions |
| `pentaho_logging` | Audit logging | Action logs, session logs |
| `pentaho_mart` | Operations mart | Performance metrics |

### Data Flow

```
User Browser
     │
     ▼
┌─────────────────────────────────────────┐
│           Pentaho Server                │
│  ┌─────────────────────────────────┐   │
│  │         Tomcat 9.x              │   │
│  │  ┌───────────────────────────┐  │   │
│  │  │     Pentaho Platform      │  │   │
│  │  │  ┌─────────────────────┐  │  │   │
│  │  │  │ Spring Security     │  │  │   │ ◄── Authentication
│  │  │  └─────────────────────┘  │  │   │
│  │  │  ┌─────────────────────┐  │  │   │
│  │  │  │ JackRabbit (JCR)    │──┼──┼───┼─► MySQL: jackrabbit
│  │  │  └─────────────────────┘  │  │   │
│  │  │  ┌─────────────────────┐  │  │   │
│  │  │  │ Quartz Scheduler    │──┼──┼───┼─► MySQL: quartz
│  │  │  └─────────────────────┘  │  │   │
│  │  │  ┌─────────────────────┐  │  │   │
│  │  │  │ Hibernate ORM       │──┼──┼───┼─► MySQL: hibernate
│  │  │  └─────────────────────┘  │  │   │
│  │  └───────────────────────────┘  │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Volume Architecture

```
Named Volumes (Persistent Data):
├── pentaho_mysql_data    → /var/lib/mysql (MySQL data files)
├── pentaho_solutions     → /opt/pentaho/pentaho-server/pentaho-solutions
└── pentaho_data          → /opt/pentaho/pentaho-server/data

Bind Mounts (Configuration):
├── ./softwareOverride    → /docker-entrypoint-init (read-only)
├── ./config/.kettle      → /home/pentaho/.kettle
├── ./config/.pentaho     → /home/pentaho/.pentaho
└── ./db_init_mysql       → /docker-entrypoint-initdb.d (read-only)
```

---

## 4. Project Structure Walkthrough

### Directory Layout

```
pentaho-mysql-ubuntu/
├── docker/                           # Docker build context
│   ├── Dockerfile                    # Multi-stage Pentaho image build
│   ├── entrypoint/
│   │   └── docker-entrypoint.sh      # Container startup script
│   └── stagedArtifacts/              # Place Pentaho ZIP here
│       └── pentaho-server-ee-11.0.0.0-237.zip
│
├── softwareOverride/                 # Configuration overlays
│   ├── 1_drivers/                    # JDBC drivers (processed first)
│   │   └── tomcat/lib/
│   │       └── mysql-connector-j-8.3.0.jar
│   ├── 2_repository/                 # Database configuration
│   │   ├── pentaho-solutions/system/
│   │   └── tomcat/webapps/pentaho/META-INF/
│   ├── 3_security/                   # Authentication settings
│   │   └── pentaho-solutions/system/
│   └── 4_others/                     # Miscellaneous config
│       ├── pentaho-solutions/system/
│       └── tomcat/
│
├── db_init_mysql/                    # MySQL initialization scripts
│   ├── 01_create_jackrabbit.sql
│   ├── 02_create_quartz.sql
│   ├── 03_create_hibernate.sql
│   ├── 04_create_pentaho_logging.sql
│   └── 05_create_pentaho_mart.sql
│
├── config/                           # Runtime configuration
│   ├── .kettle/                      # PDI settings
│   └── .pentaho/                     # User preferences
│
├── scripts/                          # Utility scripts
│   ├── backup-mysql.sh               # Database backup
│   ├── restore-mysql.sh              # Database restore
│   └── validate-deployment.sh        # Health checks
│
├── docker-compose.yml                # Container orchestration
├── .env.template                     # Environment template
├── deploy.sh                         # Deployment automation
└── Makefile                          # Build shortcuts
```

### The softwareOverride System

The softwareOverride directory is the key customization mechanism. During container startup, the entrypoint script copies these files into the Pentaho installation:

**Processing Order:**
```
1_drivers/     →  JDBC drivers loaded first
2_repository/  →  Database connections configured
3_security/    →  Authentication initialized
4_others/      →  Final customizations applied
```

**How it works:**
```bash
# From docker-entrypoint.sh
for dir in $(find /docker-entrypoint-init/ -mindepth 1 -maxdepth 1 -type d | sort); do
    if [ -f "$dir/.ignore" ]; then
        echo "Skipping $dir (contains .ignore file)"
        continue
    fi
    cp -a "$dir/." "$PENTAHO_SERVER_PATH"
done
```

---

## 5. Step-by-Step Deployment

### Step 1: Clone the Project

```bash
# Navigate to your home directory
cd ~

# Clone or copy the project
git clone <repository-url> pentaho-mysql-ubuntu
# OR
cp -r /path/to/pentaho-mysql-ubuntu ~/pentaho-mysql-ubuntu

cd pentaho-mysql-ubuntu
```

### Step 2: Stage the Pentaho Archive

```bash
# Copy the Pentaho Server ZIP to staged artifacts
cp /path/to/pentaho-server-ee-11.0.0.0-237.zip docker/stagedArtifacts/

# Verify the file exists
ls -la docker/stagedArtifacts/
```

**Expected output:**
```
-rw-r--r-- 1 user user 2147483648 Jan 12 10:00 pentaho-server-ee-11.0.0.0-237.zip
```

### Step 3: Configure Environment

```bash
# Create .env file from template
cp .env.template .env

# Edit configuration (optional)
nano .env
```

**Key environment variables:**
```bash
# .env file
PENTAHO_VERSION=11.0.0.0-237           # Must match ZIP filename
PENTAHO_IMAGE_NAME=pentaho/pentaho-server
PENTAHO_IMAGE_TAG=11.0.0.0-237

# Ports
PENTAHO_HTTP_PORT=8090                  # Web UI access
PENTAHO_HTTPS_PORT=8443                 # Secure access
MYSQL_PORT=3306                         # Database port
ADMINER_PORT=8050                       # DB admin UI

# Memory (adjust based on available RAM)
PENTAHO_MIN_MEMORY=2048m
PENTAHO_MAX_MEMORY=4096m

# MySQL root password
MYSQL_ROOT_PASSWORD=password            # CHANGE IN PRODUCTION!
```

### Step 4: Build the Docker Image

```bash
# Build the Pentaho Server image
docker compose build pentaho-server

# This will take 5-10 minutes on first build
# Subsequent builds are faster due to layer caching
```

**What happens during build:**
1. **Stage 1 (install_unpack):** Extracts Pentaho ZIP and optional plugins
2. **Stage 2 (pack):** Creates runtime image with Java and configuration

### Step 5: Start the Containers

```bash
# Start all services
docker compose up -d

# Watch the logs (optional)
docker compose logs -f pentaho-server
```

**Startup sequence:**
1. MySQL starts and initializes databases (~30 seconds)
2. MySQL health check passes
3. Pentaho Server starts (~2 minutes)
4. Configuration overlays applied
5. Tomcat initializes Pentaho platform
6. Health check passes → container becomes "healthy"

### Step 6: Verify Deployment

```bash
# Check container status
docker compose ps
```

**Expected output:**
```
NAME              IMAGE                                 STATUS
pentaho-adminer   adminer:latest                        Up (healthy)
pentaho-mysql     mysql:8.0                             Up (healthy)
pentaho-server    pentaho/pentaho-server:11.0.0.0-237   Up (healthy)
```

```bash
# Test HTTP response
curl -I http://localhost:8090/pentaho/Login
```

**Expected output:**
```
HTTP/1.1 200
Content-Type: text/html;charset=UTF-8
```

### Step 7: Access Pentaho Server

Open your web browser and navigate to:

**URL:** `http://localhost:8090/pentaho`

**Default Credentials:**
| Username | Password | Role |
|----------|----------|------|
| admin | password | Administrator |
| suzy | password | Power User |
| pat | password | Business Analyst |
| tiffany | password | Report Author |

---

## 6. Configuration Deep-Dive

### JDBC Drivers

**Location:** `softwareOverride/1_drivers/tomcat/lib/`

The MySQL JDBC driver is required for Pentaho to connect to its repository databases.

**Current driver:** `mysql-connector-j-8.3.0.jar`

**Adding additional drivers:**
```bash
# PostgreSQL
cp postgresql-42.7.1.jar softwareOverride/1_drivers/tomcat/lib/

# Oracle
cp ojdbc11.jar softwareOverride/1_drivers/tomcat/lib/

# SQL Server
cp mssql-jdbc-12.4.2.jre11.jar softwareOverride/1_drivers/tomcat/lib/

# Rebuild container after adding drivers
docker compose build pentaho-server
docker compose up -d pentaho-server
```

### Database Repository Configuration

**Key files in `softwareOverride/2_repository/`:**

| File | Purpose |
|------|---------|
| `tomcat/webapps/pentaho/META-INF/context.xml` | JNDI datasource definitions |
| `pentaho-solutions/system/jackrabbit/repository.xml` | JCR repository settings |
| `pentaho-solutions/system/hibernate/hibernate-settings.xml` | Hibernate ORM config |
| `pentaho-solutions/system/scheduler-plugin/quartz/quartz.properties` | Job scheduler settings |

**JNDI Datasources (context.xml):**
```xml
<Resource name="jdbc/Hibernate"
          type="javax.sql.DataSource"
          url="jdbc:mysql://repository:3306/hibernate"
          username="hibuser"
          password="password"/>

<Resource name="jdbc/Quartz"
          type="javax.sql.DataSource"
          url="jdbc:mysql://repository:3306/quartz"
          username="quartz_user"
          password="password"/>
```

### Security/Authentication

**Location:** `softwareOverride/3_security/pentaho-solutions/system/`

**Authentication methods:**

| Method | File | Use Case |
|--------|------|----------|
| Memory | `applicationContext-spring-security-memory.xml` | Development/testing |
| Hibernate | `applicationContext-spring-security-hibernate.properties` | Production |
| LDAP | `applicationContext-spring-security-ldap.properties` | Enterprise |

**Switching to Hibernate authentication:**

1. Edit `softwareOverride/4_others/pentaho-solutions/system/security.properties`:
   ```properties
   provider=hibernate
   ```

2. Rebuild and restart:
   ```bash
   docker compose build pentaho-server
   docker compose up -d pentaho-server
   ```

### JVM Memory Tuning

**Via environment variables (.env):**
```bash
PENTAHO_MIN_MEMORY=4096m    # -Xms4g
PENTAHO_MAX_MEMORY=8192m    # -Xmx8g
```

**Via startup script (advanced):**

Edit `softwareOverride/4_others/tomcat/bin/startup.sh`:
```bash
export CATALINA_OPTS="-Xms4g -Xmx8g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

**Memory guidelines:**

| Users | Min Memory | Max Memory |
|-------|------------|------------|
| 1-10 | 2 GB | 4 GB |
| 10-50 | 4 GB | 8 GB |
| 50-100 | 8 GB | 16 GB |
| 100+ | 16 GB | 32 GB |

---

## 7. Common Issues & Solutions

### Issue: Container Shows "unhealthy"

**Symptom:**
```
pentaho-server   Up (unhealthy)
```

**Cause 1:** Pentaho still starting (wait longer)
```bash
# Check startup progress
docker compose logs -f pentaho-server | grep -i "started\|error"
```

**Cause 2:** Health check failing
```bash
# Test health endpoint from inside container
docker exec pentaho-server curl -s http://localhost:8080/pentaho/Login
```

**Cause 3:** curl not installed (fixed in this version)
```bash
# Verify curl is present
docker exec pentaho-server curl --version
```

### Issue: MySQL Connection Refused

**Symptom:**
```
Communications link failure - Connection refused
```

**Solutions:**

1. Verify MySQL is running:
   ```bash
   docker compose ps mysql
   ```

2. Check MySQL logs:
   ```bash
   docker compose logs mysql
   ```

3. Verify hostname resolution:
   ```bash
   docker exec pentaho-server ping -c 3 repository
   ```

### Issue: Permission Denied Errors

**Symptom:**
```
java.io.FileNotFoundException: ... (Permission denied)
```

**Solutions:**

1. Check file ownership:
   ```bash
   docker exec pentaho-server ls -la /opt/pentaho/pentaho-server/
   ```

2. For log files, use Docker logs instead of bind mount:
   ```bash
   docker compose logs pentaho-server
   ```

3. Fix ownership if needed:
   ```bash
   docker exec -u root pentaho-server chown -R pentaho:pentaho /opt/pentaho/pentaho-server/logs
   ```

### Issue: Port Already in Use

**Symptom:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:8090: bind: address already in use
```

**Solutions:**

1. Find what's using the port:
   ```bash
   sudo lsof -i :8090
   ```

2. Change port in .env:
   ```bash
   PENTAHO_HTTP_PORT=8091
   ```

3. Restart:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Issue: Out of Memory

**Symptom:**
```
java.lang.OutOfMemoryError: Java heap space
```

**Solutions:**

1. Increase memory in .env:
   ```bash
   PENTAHO_MAX_MEMORY=8192m
   ```

2. Restart container:
   ```bash
   docker compose up -d pentaho-server
   ```

---

## 8. Production Considerations

### Security Hardening

**1. Change Default Passwords**

```bash
# MySQL root password (in .env)
MYSQL_ROOT_PASSWORD=your_secure_password_here

# Update context.xml with matching passwords
# Edit: softwareOverride/2_repository/tomcat/webapps/pentaho/META-INF/context.xml
```

**2. Enable HTTPS**

Edit `softwareOverride/4_others/tomcat/webapps/pentaho/WEB-INF/web.xml`:
```xml
<security-constraint>
    <web-resource-collection>
        <web-resource-name>Secured</web-resource-name>
        <url-pattern>/*</url-pattern>
    </web-resource-collection>
    <user-data-constraint>
        <transport-guarantee>CONFIDENTIAL</transport-guarantee>
    </user-data-constraint>
</security-constraint>
```

**3. Restrict Network Access**

```yaml
# docker-compose.yml - Remove external port mappings
ports:
  # - "${MYSQL_PORT:-3306}:3306"  # Comment out for production
```

### Backup Strategy

**Database backup:**
```bash
# Manual backup
./scripts/backup-mysql.sh

# Automated backup (cron)
0 2 * * * /home/pentaho/pentaho-mysql-ubuntu/scripts/backup-mysql.sh
```

**Volume backup:**
```bash
# Stop containers
docker compose down

# Backup volumes
docker run --rm -v pentaho_mysql_data:/data -v $(pwd)/backups:/backup \
    alpine tar czf /backup/mysql_data_$(date +%Y%m%d).tar.gz /data

docker run --rm -v pentaho_solutions:/data -v $(pwd)/backups:/backup \
    alpine tar czf /backup/solutions_$(date +%Y%m%d).tar.gz /data

# Restart containers
docker compose up -d
```

### Monitoring

**Health check status:**
```bash
watch -n 5 'docker compose ps'
```

**Resource usage:**
```bash
docker stats pentaho-server pentaho-mysql
```

**Log monitoring:**
```bash
docker compose logs -f --tail=100
```

### High Availability Considerations

For production deployments requiring high availability:

1. **Database:** Use MySQL replication or managed database service
2. **Load Balancing:** Deploy multiple Pentaho containers behind a load balancer
3. **Session Replication:** Configure Tomcat session clustering
4. **Shared Storage:** Use NFS or object storage for pentaho-solutions

---

## 9. Hands-On Exercises

### Exercise 1: Fresh Deployment

**Objective:** Deploy Pentaho Server from scratch

**Steps:**

1. Clean up any existing deployment:
   ```bash
   docker compose down -v
   docker system prune -f
   ```

2. Follow the deployment steps (Section 5)

3. Verify all containers are healthy:
   ```bash
   docker compose ps
   ```

4. Log in to Pentaho as admin

**Success Criteria:**
- All three containers show "healthy"
- Web UI accessible at http://localhost:8090/pentaho
- Can log in with admin/password

### Exercise 2: Add a Custom JDBC Driver

**Objective:** Add PostgreSQL driver for external data sources

**Steps:**

1. Download the PostgreSQL JDBC driver:
   ```bash
   wget -P softwareOverride/1_drivers/tomcat/lib/ \
       https://jdbc.postgresql.org/download/postgresql-42.7.1.jar
   ```

2. Rebuild the container:
   ```bash
   docker compose build pentaho-server
   docker compose up -d pentaho-server
   ```

3. Verify the driver is loaded:
   ```bash
   docker exec pentaho-server ls -la /opt/pentaho/pentaho-server/tomcat/lib/ | grep postgres
   ```

**Success Criteria:**
- PostgreSQL driver visible in container
- Can create PostgreSQL data source in Pentaho

### Exercise 3: Create and Restore Backup

**Objective:** Test backup and restore procedures

**Steps:**

1. Create some content in Pentaho (e.g., upload a report)

2. Create backup:
   ```bash
   ./scripts/backup-mysql.sh
   ls -la backups/
   ```

3. Delete the content in Pentaho

4. Restore from backup:
   ```bash
   ./scripts/restore-mysql.sh backups/pentaho_backup_YYYYMMDD_HHMMSS.sql
   ```

5. Verify content is restored

**Success Criteria:**
- Backup file created successfully
- Restore completes without errors
- Content is restored in Pentaho

### Exercise 4: Switch Authentication Method

**Objective:** Configure Hibernate-based authentication

**Steps:**

1. View current authentication method:
   ```bash
   cat softwareOverride/4_others/pentaho-solutions/system/security.properties
   ```

2. Change to Hibernate:
   ```bash
   echo "provider=hibernate" > softwareOverride/4_others/pentaho-solutions/system/security.properties
   ```

3. Rebuild and restart:
   ```bash
   docker compose build pentaho-server
   docker compose up -d pentaho-server
   ```

4. Verify by checking logs:
   ```bash
   docker compose logs pentaho-server | grep -i "hibernate\|security"
   ```

**Success Criteria:**
- Container starts successfully
- Authentication works with database-stored users

---

## 10. Appendix

### Useful Commands Reference

```bash
# Container Management
docker compose up -d              # Start all containers
docker compose down               # Stop all containers
docker compose down -v            # Stop and remove volumes
docker compose restart            # Restart all containers
docker compose build --no-cache   # Rebuild without cache

# Logs
docker compose logs -f            # Follow all logs
docker compose logs pentaho-server -f --tail=100  # Follow Pentaho logs

# Shell Access
docker exec -it pentaho-server bash    # Shell into Pentaho container
docker exec -it pentaho-mysql mysql -uroot -p  # MySQL shell

# Status
docker compose ps                 # Container status
docker stats                      # Resource usage

# Cleanup
docker system prune -f            # Remove unused data
docker volume prune -f            # Remove unused volumes
```

### Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| PENTAHO_VERSION | 11.0.0.0-237 | Pentaho version |
| PENTAHO_HTTP_PORT | 8090 | Web UI port |
| PENTAHO_HTTPS_PORT | 8443 | HTTPS port |
| PENTAHO_MIN_MEMORY | 2048m | JVM minimum heap |
| PENTAHO_MAX_MEMORY | 4096m | JVM maximum heap |
| MYSQL_PORT | 3306 | MySQL port |
| MYSQL_ROOT_PASSWORD | password | MySQL root password |
| ADMINER_PORT | 8050 | Adminer port |
| LICENSE_URL | (empty) | URL to download EE license |

### File Locations Inside Container

| Path | Description |
|------|-------------|
| /opt/pentaho/pentaho-server | Pentaho installation root |
| /opt/pentaho/pentaho-server/tomcat | Tomcat application server |
| /opt/pentaho/pentaho-server/pentaho-solutions | Reports, dashboards, config |
| /opt/pentaho/pentaho-server/data | Local data files |
| /home/pentaho/.pentaho | User preferences |
| /home/pentaho/.kettle | PDI configuration |
| /docker-entrypoint-init | Mounted softwareOverride (read-only) |

### Troubleshooting Checklist

- [ ] Is Docker running? `systemctl status docker`
- [ ] Is the Pentaho ZIP in stagedArtifacts? `ls docker/stagedArtifacts/`
- [ ] Is the .env file configured? `cat .env`
- [ ] Are all containers running? `docker compose ps`
- [ ] Are containers healthy? `docker compose ps` shows "healthy"
- [ ] Can you reach the web UI? `curl -I http://localhost:8090/pentaho/Login`
- [ ] Any errors in logs? `docker compose logs --tail=100`
- [ ] Is MySQL accessible? `docker exec pentaho-mysql mysqladmin ping -uroot -p`
- [ ] Sufficient disk space? `df -h`
- [ ] Sufficient memory? `free -h`

---

## Congratulations!

You have completed the Pentaho Server 11 Docker deployment workshop. You should now be able to:

- Deploy and manage Pentaho Server in Docker containers
- Configure the application using the softwareOverride system
- Troubleshoot common deployment issues
- Implement production-ready configurations

For additional support:
- **Documentation:** See README.md, ARCHITECTURE.md, TROUBLESHOOTING.md
- **Hitachi Vantara Support:** https://support.hitachivantara.com
- **Community Forum:** https://community.hitachivantara.com

---

*Workshop Version: 1.0*
*Last Updated: January 2026*
