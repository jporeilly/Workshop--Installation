--
-- note: this script assumes pg_hba.conf is configured correctly
--

-- \connect postgres postgres

DROP DATABASE IF EXISTS jackrabbit;

-- Drop user second
DROP ROLE IF EXISTS jcr_user;

-- Create user
CREATE USER jcr_user WITH PASSWORD 'password';

GRANT jcr_user TO postgres;
-- Create the database with that user as owner
CREATE DATABASE jackrabbit WITH OWNER = jcr_user ENCODING = 'UTF8';

GRANT ALL PRIVILEGES ON DATABASE jackrabbit to jcr_user;  