--
-- note: this script assumes pg_hba.conf is configured correctly
--

-- \connect postgres postgres

drop database if exists jackrabbit;
drop user if exists jcr_user;

CREATE USER jcr_user PASSWORD 'password';

CREATE DATABASE jackrabbit ENCODING = 'UTF8';

GRANT ALL PRIVILEGES ON DATABASE jackrabbit to jcr_user;

\c jackrabbit postgres
ALTER SCHEMA public OWNER TO postgres;
GRANT USAGE, CREATE ON SCHEMA public TO jcr_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO jcr_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO jcr_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO jcr_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO jcr_user;