# Pentaho Home Configuration

This folder is mounted to `$PENTAHO_HOME` (`/home/pentaho`) in the container.

## Directory Structure

| Folder | Purpose |
|--------|---------|
| `.kettle/` | PDI/Kettle configuration (kettle.properties, repositories.xml) |
| `.pentaho/` | Pentaho user preferences and license files |

## Optional Configurations

You can also add:
- `.aws/` - AWS credentials for S3 access
- `.ssh/` - SSH keys for SFTP connections

## Notes

- Files here persist across container restarts
- Add `kettle.properties` to `.kettle/` for custom PDI settings
- License files are stored in `.pentaho/`
