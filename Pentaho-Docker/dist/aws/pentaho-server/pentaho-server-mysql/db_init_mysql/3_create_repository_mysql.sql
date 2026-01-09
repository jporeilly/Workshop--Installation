CREATE DATABASE IF NOT EXISTS `hibernate` DEFAULT CHARACTER SET latin1;

USE hibernate;

CREATE USER 'hibuser'@'%' identified by 'password';
GRANT ALL PRIVILEGES ON hibernate.* TO 'hibuser'@'%' WITH GRANT OPTION;

commit;
