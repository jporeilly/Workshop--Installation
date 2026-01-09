
CREATE DATABASE IF NOT EXISTS `jackrabbit` DEFAULT CHARACTER SET latin1;

CREATE USER 'jcr_user'@'%' identified by 'password';

GRANT ALL PRIVILEGES ON jackrabbit.* TO 'jcr_user'@'%' WITH GRANT OPTION;

commit;