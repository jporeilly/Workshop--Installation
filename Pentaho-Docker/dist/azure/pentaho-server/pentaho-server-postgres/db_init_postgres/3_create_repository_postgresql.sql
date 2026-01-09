--
-- note: this script assumes pg_hba.conf is configured correctly
--

-- \connect postgres postgres

drop database if exists hibernate;
drop user if exists hibuser;

CREATE USER hibuser PASSWORD 'password';
		GRANT hibuser TO postgres;
		GRANT azure_pg_admin TO hibuser;

CREATE DATABASE hibernate WITH OWNER = hibuser ENCODING = 'UTF8';

GRANT ALL PRIVILEGES ON DATABASE hibernate to hibuser;
