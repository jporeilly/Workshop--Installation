# Staged Artifacts

This folder should contain the pre-downloaded Pentaho Server distribution ZIP files required for building the Docker image.

## Required Files

Download the following file from the Hitachi Vantara support portal and place it in this folder:

- **`pentaho-server-ce-11.0.0.0-237.zip`** (Community Edition)
  
  OR
  
- **`pentaho-server-ee-11.0.0.0-237.zip`** (Enterprise Edition)

## Download Location

- **Community Edition**: https://sourceforge.net/projects/pentaho/files/
- **Enterprise Edition**: https://support.pentaho.com/ (requires valid support credentials)

## File Naming

The Dockerfile expects the file to match the pattern `pentaho-server-*.zip`. If your downloaded file has a different name, either:

1. Rename it to match the expected pattern, or
2. Update the `COPY` instruction in the Dockerfile

## After Placing Files

Once the ZIP file is in this folder, you can build the Docker image:

```bash
cd assemblies/pentaho-server
docker build -t pentaho/pentaho-server:11.0.0.0-237 .
```

## Notes

- Ensure you have sufficient disk space (the extracted Pentaho Server can be several GB)
- The ZIP file will be extracted during the Docker build process
- Do not commit the ZIP file to version control (add to .gitignore)
