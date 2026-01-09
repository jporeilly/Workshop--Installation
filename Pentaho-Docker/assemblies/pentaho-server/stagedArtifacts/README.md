# Staged Artifacts for Offline Deployment

This folder is used for **offline/air-gapped deployments** where the Docker build process cannot download artifacts from the internet.

## Overview

When building the Pentaho Server Docker image, the Dockerfile copies files from this folder into the build context. For offline deployments, you must manually download and place the required ZIP files here before running `docker build`.

## Required Files

| File | Description | Required |
|------|-------------|----------|
| `pentaho-server-ee-11.0.0.0-237.zip` | Main Pentaho Server EE distribution | **Yes** |

## Optional Plugin Files

| File | Description | Required |
|------|-------------|----------|
| `paz-plugin-ee-11.0.0.0-237.zip` | Pentaho Analyzer - OLAP analysis tool | No |
| `pir-plugin-ee-11.0.0.0-237.zip` | Pentaho Interactive Reports - Ad-hoc reporting | No |
| `pdd-plugin-ee-11.0.0.0-237.zip` | Pentaho Dashboard Designer - Dashboard creation | No |

## How to Obtain Files

1. Log in to the [Hitachi Vantara Support Portal](https://support.hitachivantara.com)
2. Navigate to **Software Downloads** > **Pentaho**
3. Select **Pentaho Server 11.0** and download the required ZIP files
4. Copy the downloaded files to this `stagedArtifacts/` folder

## File Naming Convention

The Dockerfile expects files to follow this naming pattern:

```
pentaho-server-ee-{VERSION}.zip
paz-plugin-ee-{VERSION}.zip
pir-plugin-ee-{VERSION}.zip
pdd-plugin-ee-{VERSION}.zip
```

Where `{VERSION}` matches the `PENTAHO_VERSION` build argument (default: `11.0.0.0-237`).

## Changing Versions

To use a different Pentaho version:

1. Download the corresponding version ZIP files
2. Update the `PENTAHO_VERSION` in:
   - `Dockerfile` (line 24): `ARG PENTAHO_VERSION=11.0.0.0-237`
   - `.env` file: `PENTAHO_VERSION=11.0.0.0-237`

## Build Command

After placing the files here, build the Docker image:

```bash
cd assemblies/pentaho-server
docker build -t pentaho/pentaho-server:11.0.0.0-237 .
```

## Troubleshooting

**Error: "File pentaho-server-ee-11.0.0.0-237.zip Not Found"**

- Verify the ZIP file is in this folder
- Check the filename matches exactly (case-sensitive)
- Ensure the version number matches `PENTAHO_VERSION` in the Dockerfile

## Note

This folder is gitignored (except for this README) to prevent large binary files from being committed to version control.

