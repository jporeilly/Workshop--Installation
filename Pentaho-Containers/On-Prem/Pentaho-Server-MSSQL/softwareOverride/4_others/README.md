# 4_others - Additional Configuration

## Table of Contents

- [Purpose](#purpose)
- [Processing Order](#processing-order)
- [Directory Structure](#directory-structure)
- [Key Configuration Files](#key-configuration-files)
- [OAuth/SAML Configuration](#oauthsaml-configuration)
- [Sample Data](#sample-data)
- [Customization Examples](#customization-examples)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

## Purpose

This directory contains miscellaneous configuration files for Tomcat, default users, sample data, and other application-level settings.

## Processing Order

This directory is processed **fourth** (last) during container startup, after security configuration.

## Directory Structure

```
4_others/
├── README.md                                    # This file
├── pentaho-solutions/
│   └── system/
│       ├── applicationContext-spring-security-oauth.properties
│       ├── defaultUser.spring.properties        # Default user settings
│       ├── defaultUser.spring.xml               # Default user definition
│       ├── pentaho.xml                          # Core Pentaho settings
│       └── security.properties                  # Security provider selection
├── tomcat/
│   ├── bin/
│   │   └── startup.sh                           # Tomcat startup script
│   └── webapps/
│       └── pentaho/
│           └── WEB-INF/
│               └── web.xml                      # Servlet configuration
└── data/
    └── hsqldb/
        ├── sampledata.properties                # Sample database config
        └── sampledata.script                    # Sample data SQL
```

## Key Configuration Files

### security.properties

**Location:** `pentaho-solutions/system/security.properties`

Selects the active authentication provider:

```properties
# Options: memory, hibernate, ldap, saml
provider=memory
```

### pentaho.xml

**Location:** `pentaho-solutions/system/pentaho.xml`

Core Pentaho Server settings:
- Solution path
- System path
- Publisher settings
- Logging configuration

### defaultUser.spring.properties

**Location:** `pentaho-solutions/system/defaultUser.spring.properties`

Default user creation settings:

```properties
defaultUser.user=admin
defaultUser.password=password
defaultUser.roles=Administrator
```

### web.xml

**Location:** `tomcat/webapps/pentaho/WEB-INF/web.xml`

Servlet configuration:
- Session timeout
- Filter mappings
- Security constraints
- Welcome files

### startup.sh

**Location:** `tomcat/bin/startup.sh`

Tomcat startup script with JVM options:
- Memory settings
- Garbage collection
- System properties

## OAuth/SAML Configuration

### OAuth Properties

**File:** `applicationContext-spring-security-oauth.properties`

Configure OAuth 2.0 integration:

```properties
oauth.clientId=your_client_id
oauth.clientSecret=your_client_secret
oauth.authorizationEndpoint=https://idp.example.com/oauth/authorize
oauth.tokenEndpoint=https://idp.example.com/oauth/token
```

## Sample Data

The `data/hsqldb/` directory contains sample database configuration for demonstration purposes:

- `sampledata.properties` - HSQLDB connection settings
- `sampledata.script` - Sample data initialization SQL

These are typically used for demo installations and can be removed for production.

## Customization Examples

### Change Session Timeout

Edit `web.xml`:

```xml
<session-config>
    <session-timeout>60</session-timeout>  <!-- minutes -->
</session-config>
```

### Configure SSL Redirect

Edit `web.xml` to force HTTPS:

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

### Increase JVM Memory

Edit `startup.sh`:

```bash
export CATALINA_OPTS="-Xms4g -Xmx8g ..."
```

## Troubleshooting

### Slow Startup

**Cause:** JVM memory too low
**Solution:** Increase memory in startup.sh or .env file

### Session Expires Too Quickly

**Cause:** Short session timeout
**Solution:** Increase session-timeout in web.xml

### OAuth Login Fails

**Cause:** Incorrect OAuth configuration
**Solution:** Verify OAuth properties match identity provider settings

## Related Documentation

- [README.md](../../README.md) - Main project documentation
- [QUICKSTART.md](../../QUICKSTART.md) - Quick start guide
- [CONFIGURATION.md](../../CONFIGURATION.md) - Configuration reference
- [1_drivers/README.md](../1_drivers/README.md) - JDBC drivers documentation
- [3_security/README.md](../3_security/README.md) - Security configuration
