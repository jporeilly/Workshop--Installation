--
-- Pentaho Server 11 - PostgreSQL 17 Database Initialization
-- Consolidated script for Docker container initialization
-- This script runs as postgres superuser in docker-entrypoint-initdb.d
--
-- Databases: jackrabbit, quartz, hibernate
-- Users: jcr_user, pentaho_user, hibuser
--

-- ============================================================================
-- STEP 1: Create all database users with scram-sha-256 passwords
-- ============================================================================

-- Drop existing users if they exist (clean install)
DROP USER IF EXISTS jcr_user;
DROP USER IF EXISTS pentaho_user;
DROP USER IF EXISTS hibuser;

-- Create users with LOGIN privilege
CREATE USER jcr_user WITH LOGIN PASSWORD 'password';
CREATE USER pentaho_user WITH LOGIN PASSWORD 'password';
CREATE USER hibuser WITH LOGIN PASSWORD 'password';

-- ============================================================================
-- STEP 2: Create all databases with proper ownership
-- ============================================================================

-- Drop existing databases if they exist (clean install)
DROP DATABASE IF EXISTS jackrabbit;
DROP DATABASE IF EXISTS quartz;
DROP DATABASE IF EXISTS hibernate;

-- Create Jackrabbit database (JCR repository)
CREATE DATABASE jackrabbit 
    WITH OWNER = jcr_user 
    ENCODING = 'UTF8' 
    TEMPLATE = template0
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- Create Quartz database (Scheduler)
CREATE DATABASE quartz 
    WITH OWNER = pentaho_user 
    ENCODING = 'UTF8' 
    TEMPLATE = template0
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- Create Hibernate database (Repository/Audit)
CREATE DATABASE hibernate 
    WITH OWNER = hibuser 
    ENCODING = 'UTF8' 
    TEMPLATE = template0
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- ============================================================================
-- STEP 3: Grant database-level privileges
-- ============================================================================

GRANT ALL PRIVILEGES ON DATABASE jackrabbit TO jcr_user;
GRANT ALL PRIVILEGES ON DATABASE quartz TO pentaho_user;
GRANT ALL PRIVILEGES ON DATABASE hibernate TO hibuser;

-- Grant CONNECT to all Pentaho users on all databases for cross-database access
GRANT CONNECT ON DATABASE jackrabbit TO pentaho_user, hibuser;
GRANT CONNECT ON DATABASE quartz TO jcr_user, hibuser;
GRANT CONNECT ON DATABASE hibernate TO jcr_user, pentaho_user;
