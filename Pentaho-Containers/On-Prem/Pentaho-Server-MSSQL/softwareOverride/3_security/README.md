# 3_security - Authentication and Security Configuration

## Table of Contents

- [Purpose](#purpose)
- [Processing Order](#processing-order)
- [Directory Structure](#directory-structure)
- [Authentication Methods](#authentication-methods)
- [Switching Authentication Methods](#switching-authentication-methods)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

## Purpose

This directory contains security configuration files for Pentaho Server authentication and authorization. It defines how users are authenticated and what access they have.

## Processing Order

This directory is processed **third** during container startup, after repository configuration.

## Directory Structure

```
3_security/
├── README.md                                              # This file
└── pentaho-solutions/
    └── system/
        ├── applicationContext-spring-security-hibernate.properties
        └── applicationContext-spring-security-memory.xml
```

## Authentication Methods

Pentaho supports multiple authentication backends. The active method is configured in `security.properties` (in 4_others/).

### Memory-Based Authentication (Default)

**File:** `applicationContext-spring-security-memory.xml`

Users are defined directly in XML. Suitable for development and testing.

```xml
<user name="admin" password="{SHA}..." authorities="Administrator"/>
<user name="suzy" password="{SHA}..." authorities="Power User"/>
```

**Default Users:**
| Username | Password | Role |
|----------|----------|------|
| admin | password | Administrator |
| suzy | password | Power User |
| pat | password | Business Analyst |
| tiffany | password | Report Author |

### Hibernate-Based Authentication

**File:** `applicationContext-spring-security-hibernate.properties`

Users are stored in the SQL Server database. Recommended for production.

```properties
datasource.driver.classname=com.microsoft.sqlserver.jdbc.SQLServerDriver
datasource.url=jdbc:sqlserver://repository:1433;databaseName=hibernate;encrypt=false;trustServerCertificate=true
datasource.username=hibuser
datasource.password=password
```

### LDAP Authentication

For enterprise environments, configure LDAP integration:

1. Create `applicationContext-spring-security-ldap.properties`
2. Update `security.properties` to use LDAP provider
3. Configure LDAP server connection details

### OAuth/SAML SSO

For single sign-on integration:

1. Configure OAuth properties in 4_others/
2. Set up identity provider (IdP) integration
3. Update security provider settings

## Switching Authentication Methods

### Enable Hibernate Authentication

1. Edit `softwareOverride/4_others/pentaho-solutions/system/security.properties`:
   ```properties
   provider=hibernate
   ```

2. Rebuild and restart:
   ```bash
   docker compose build --no-cache pentaho-server
   docker compose up -d pentaho-server
   ```

### Enable LDAP Authentication

1. Create LDAP configuration file
2. Update `security.properties`:
   ```properties
   provider=ldap
   ```

## Security Best Practices

### For Production

1. **Change default passwords** - Update all user passwords after first login
2. **Use Hibernate authentication** - Store users in database, not XML
3. **Enable HTTPS** - Configure SSL/TLS for secure connections
4. **Implement LDAP/SSO** - Integrate with enterprise identity management
5. **Regular audits** - Review user access and permissions

### Password Encoding

Passwords in memory-based authentication are SHA-encoded:

```bash
# Generate SHA-encoded password
echo -n "your_password" | sha1sum | awk '{print $1}' | xxd -r -p | base64
```

## Troubleshooting

### Login Fails with Correct Password

**Cause:** Password encoding mismatch
**Solution:** Verify password is SHA-encoded in XML

### LDAP Connection Timeout

**Cause:** Network or firewall blocking LDAP port
**Solution:** Verify LDAP server accessibility from container

### User Roles Not Applied

**Cause:** Role mapping configuration
**Solution:** Check role definitions in security configuration

## Related Documentation

- [Main README](../../README.md) - Project overview
- [softwareOverride README](../README.md) - Override system documentation
- [CONFIGURATION.md](../../CONFIGURATION.md) - Security configuration options
