--THIS USER IS SPECIFIC TO THE DATABASE WHERE THIS SCRIPT IS TO BE RUN AND IT
--SHOULD BE A USER WITH DBA PRIVS.
--AND ALSO @pentaho should be replaced with the correct instance name

--conn admin/password@pentaho

set escape on;

CREATE TABLESPACE pentaho_tablespace DATAFILE SIZE 32M AUTOEXTEND ON NEXT 32M MAXSIZE 2048M;

drop user jcr_user cascade;

create user jcr_user identified by "password" default tablespace pentaho_tablespace quota unlimited on pentaho_tablespace temporary tablespace temp quota 5M on system;

grant create session, create procedure, create table, create trigger, create sequence to jcr_user;

--CREATE ADDITIONAL REPOSITORY TABLES
--In the following connection, please replace the RDS Oracle DB host
conn jcr_user/password@//database-2.cvpsc6yoec9o.us-east-2.rds.amazonaws.com:1521/orcl;
commit;