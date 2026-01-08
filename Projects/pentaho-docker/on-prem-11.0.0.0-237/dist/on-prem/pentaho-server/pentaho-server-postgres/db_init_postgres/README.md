# PostgreSQL 17 Database Initialization Scripts

These scripts initialize the Pentaho repository databases in PostgreSQL 17.

## Execution Order

Scripts run automatically in alphabetical order when the PostgreSQL container starts:

| Script | Purpose |
|--------|---------|
| `0_init_pentaho_databases.sql` | Creates users (jcr_user, pentaho_user, hibuser) and databases |
| `1_create_jcr_postgresql.sql` | Jackrabbit schema permissions |
| `2_create_quartz_postgresql.sql` | Quartz scheduler tables |
| `3_create_repository_postgresql.sql` | Hibernate schema permissions |
| `4_pentaho_logging_postgresql.sql` | DI logging tables |
| `5_pentaho_mart_postgresql.sql` | Operations mart tables |

## Databases Created

- **jackrabbit** - JCR content repository (owner: jcr_user)
- **quartz** - Scheduler data (owner: pentaho_user)
- **hibernate** - Audit/logging data (owner: hibuser)

## Default Credentials

All passwords are set to `password` - **change for production!**
