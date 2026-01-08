--
-- Pentaho Server 11 - PostgreSQL 17 Database Initialization
-- STEP 0: Run as postgres superuser to create pentaho user and databases
-- Per Pentaho Academy installation guide
--

-- ============================================================================
-- STEP 1: Create pentaho superuser (as per Pentaho installation guide)
-- ============================================================================

DROP USER IF EXISTS pentaho;
CREATE USER pentaho WITH LOGIN SUPERUSER PASSWORD 'password';

-- ============================================================================
-- STEP 2: Create application database users
-- ============================================================================

DROP USER IF EXISTS jcr_user;
DROP USER IF EXISTS pentaho_user;
DROP USER IF EXISTS hibuser;

CREATE USER jcr_user WITH LOGIN PASSWORD 'password';
CREATE USER pentaho_user WITH LOGIN PASSWORD 'password';
CREATE USER hibuser WITH LOGIN PASSWORD 'password';

-- ============================================================================
-- STEP 3: Create all databases owned by pentaho superuser
-- ============================================================================

DROP DATABASE IF EXISTS jackrabbit;
DROP DATABASE IF EXISTS quartz;
DROP DATABASE IF EXISTS hibernate;

CREATE DATABASE jackrabbit 
    WITH OWNER = pentaho 
    ENCODING = 'UTF8' 
    TEMPLATE = template0
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

CREATE DATABASE quartz 
    WITH OWNER = pentaho 
    ENCODING = 'UTF8' 
    TEMPLATE = template0
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

CREATE DATABASE hibernate 
    WITH OWNER = pentaho 
    ENCODING = 'UTF8' 
    TEMPLATE = template0
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- ============================================================================
-- STEP 4: Grant database-level privileges
-- ============================================================================

GRANT ALL PRIVILEGES ON DATABASE jackrabbit TO jcr_user, pentaho;
GRANT ALL PRIVILEGES ON DATABASE quartz TO pentaho_user, pentaho;
GRANT ALL PRIVILEGES ON DATABASE hibernate TO hibuser, pentaho;

-- Cross-database CONNECT privileges
GRANT CONNECT ON DATABASE jackrabbit TO pentaho_user, hibuser;
GRANT CONNECT ON DATABASE quartz TO jcr_user, hibuser;
GRANT CONNECT ON DATABASE hibernate TO jcr_user, pentaho_user;
