-- =============================================================================
-- Pentaho Server 11 - Oracle Database Initialization
-- Script 1: Create Users and Grant Privileges
-- =============================================================================
-- This script creates all users (schemas) required for Pentaho Server
-- Each user owns their own schema in Oracle (unlike MySQL separate databases)
-- =============================================================================

-- Connect to the pluggable database (FREEPDB1)
-- The gvenzl/oracle-free image runs init scripts in CDB by default,
-- so we must explicitly switch to the PDB where Pentaho will connect
ALTER SESSION SET CONTAINER = FREEPDB1;

-- -----------------------------------------------------------------------------
-- Create Jackrabbit (JCR) User
-- Used for: Content repository (reports, dashboards, data sources)
-- -----------------------------------------------------------------------------
CREATE USER jcr_user IDENTIFIED BY "password"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE TO jcr_user;
GRANT CREATE SESSION TO jcr_user;
GRANT CREATE TABLE TO jcr_user;
GRANT CREATE SEQUENCE TO jcr_user;
GRANT CREATE VIEW TO jcr_user;
GRANT UNLIMITED TABLESPACE TO jcr_user;

-- -----------------------------------------------------------------------------
-- Create Quartz User
-- Used for: Job scheduler tables
-- -----------------------------------------------------------------------------
CREATE USER pentaho_user IDENTIFIED BY "password"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE TO pentaho_user;
GRANT CREATE SESSION TO pentaho_user;
GRANT CREATE TABLE TO pentaho_user;
GRANT CREATE SEQUENCE TO pentaho_user;
GRANT UNLIMITED TABLESPACE TO pentaho_user;

-- -----------------------------------------------------------------------------
-- Create Hibernate User
-- Used for: Pentaho repository metadata, user/role info, permissions
-- -----------------------------------------------------------------------------
CREATE USER hibuser IDENTIFIED BY "password"
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

GRANT CONNECT, RESOURCE TO hibuser;
GRANT CREATE SESSION TO hibuser;
GRANT CREATE TABLE TO hibuser;
GRANT CREATE SEQUENCE TO hibuser;
GRANT CREATE VIEW TO hibuser;
GRANT UNLIMITED TABLESPACE TO hibuser;

COMMIT;
