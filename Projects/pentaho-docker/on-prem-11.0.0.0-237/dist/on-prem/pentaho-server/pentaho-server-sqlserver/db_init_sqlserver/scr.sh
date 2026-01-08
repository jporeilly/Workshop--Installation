 /opt/mssql/bin/sqlservr &
 sleep 20;
 echo "Listing contents of /docker-entrypoint-initdb.d:";
 ls -l /docker-entrypoint-initdb.d;
 for file in /docker-entrypoint-initdb.d/*.sql; do
   if [ -f "$file" ]; then
     echo "Running $file...";
     /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P password#123 -d master -C -i "$file";
   else
     echo "No .sql files found in /docker-entrypoint-initdb.d";
   fi
 done
 echo "sqlserver successfully initialized";
 wait