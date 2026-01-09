--THIS USER IS SPECIFIC TO THE DATABASE WHERE THIS SCRIPT IS TO BE RUN AND IT
--SHOULD BE A USER WITH DBA PRIVS.
--AND ALSO @pentaho should be replaced with the correct instance name

--conn admin/password@pentaho

set escape on;

-- Correcting tablespace creation with a proper datafile path
CREATE TABLESPACE pentaho_tablespace
  DATAFILE '/opt/oracle/oradata/XE/pentaho_ts01.dbf'
  SIZE 32M AUTOEXTEND ON NEXT 32M MAXSIZE 2048M;

-- Ignore error if user doesn't exist
BEGIN
   EXECUTE IMMEDIATE 'DROP USER jcr_user CASCADE';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -1918 THEN
         RAISE;
      END IF;
END;
/

-- Create user and grant permissions
CREATE USER jcr_user IDENTIFIED BY "password"
  DEFAULT TABLESPACE pentaho_tablespace
  QUOTA UNLIMITED ON pentaho_tablespace
  TEMPORARY TABLESPACE temp
  QUOTA 5M ON system;

GRANT create session, create procedure, create table, create trigger, create sequence TO jcr_user;

-- OPTIONAL: Switch to jcr_user inside same session (no external connect)
ALTER SESSION SET CURRENT_SCHEMA = jcr_user;

-- If you want to connect to it from outside, do it from your laptop using SQL Developer, not here
