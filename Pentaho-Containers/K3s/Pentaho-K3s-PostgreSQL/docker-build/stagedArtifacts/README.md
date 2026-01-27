# Pentaho Staged Artifacts

Place your Pentaho Server package and optional plugins in this directory before building the Docker image.

## Required Files

### Pentaho Server Package (Required)

**Enterprise Edition:**
```
pentaho-server-ee-11.0.0.0-237.zip
```

**Community Edition:**
```
pentaho-server-ce-11.0.0.0-237.zip
```

**How to obtain:**
- **Enterprise**: Download from Hitachi Vantara Support Portal
- **Community**: Download from SourceForge or official Pentaho site

**File size**: ~1.5 GB (Enterprise), ~800 MB (Community)

## Optional Plugin Files

The following plugins are automatically detected and installed if present:

### 1. Pentaho Analyzer (PAZ)
```
paz-plugin-ee-11.0.0.0-237.zip
```

**Description**: Interactive OLAP analysis and visualization
**License**: Enterprise Edition only
**Installation location**: `pentaho-solutions/system/analyzer`

### 2. Pentaho Interactive Reporting (PIR)
```
pir-plugin-ee-11.0.0.0-237.zip
```

**Description**: Pixel-perfect report designer
**License**: Enterprise Edition only
**Installation location**: `pentaho-solutions/system/pentaho-interactive-reporting`

### 3. Pentaho Dashboard Designer (PDD)
```
pdd-plugin-ee-11.0.0.0-237.zip
```

**Description**: Dashboard creation and customization
**License**: Enterprise Edition only
**Installation location**: `pentaho-solutions/system/dashboards`

## Example Directory Structure

After placing files, this directory should look like:

```
stagedArtifacts/
├── README.md (this file)
├── pentaho-server-ee-11.0.0.0-237.zip       # Required
├── paz-plugin-ee-11.0.0.0-237.zip           # Optional
├── pir-plugin-ee-11.0.0.0-237.zip           # Optional
└── pdd-plugin-ee-11.0.0.0-237.zip           # Optional
```

## Verification

Before building, verify files are present:

```bash
# Check for required package
ls -lh pentaho-server-*.zip

# Check for optional plugins
ls -lh *-plugin-*.zip 2>/dev/null || echo "No plugins found (optional)"

# Verify file integrity (if checksums provided)
sha256sum pentaho-server-ee-11.0.0.0-237.zip
```

## Download Sources

### Hitachi Vantara (Enterprise)
- **Portal**: https://support.pentaho.com/
- **Requirements**: Valid support contract
- **Documentation**: https://help.hitachivantara.com/

### Pentaho Community Edition
- **SourceForge**: https://sourceforge.net/projects/pentaho/
- **GitHub**: https://github.com/pentaho/
- **Maven Central**: For specific components

## Version Compatibility

Ensure all components match the same version:

| Component | Version | Required |
|-----------|---------|----------|
| Pentaho Server | 11.0.0.0-237 | Yes |
| PAZ Plugin | 11.0.0.0-237 | No |
| PIR Plugin | 11.0.0.0-237 | No |
| PDD Plugin | 11.0.0.0-237 | No |

**Mismatched versions may cause compatibility issues!**

## Build Arguments

The Dockerfile uses these build arguments:

```dockerfile
# Main package name pattern
ARG PENTAHO_INSTALLER_NAME=pentaho-server-ee  # or pentaho-server-ce
ARG PENTAHO_VERSION=11.0.0.0-237

# Plugin patterns (auto-detected if files exist)
ARG FILE_PAZ=paz-plugin-ee-${PENTAHO_VERSION}.zip
ARG FILE_PIR=pir-plugin-ee-${PENTAHO_VERSION}.zip
ARG FILE_PDD=pdd-plugin-ee-${PENTAHO_VERSION}.zip
```

### Override for Different Versions

```bash
# Build with different version
docker build \
    --build-arg PENTAHO_VERSION=11.0.0.0-xxx \
    -t pentaho-server:11.0.0.0-xxx \
    ..
```

## File Size Reference

| File | Typical Size |
|------|--------------|
| pentaho-server-ee-*.zip | ~1.5 GB |
| pentaho-server-ce-*.zip | ~800 MB |
| paz-plugin-ee-*.zip | ~50 MB |
| pir-plugin-ee-*.zip | ~100 MB |
| pdd-plugin-ee-*.zip | ~30 MB |

**Total (with all plugins)**: ~1.7 GB

## Security Notes

**Important**:
- Do NOT commit these files to version control
- Add `*.zip` to `.gitignore`
- Store securely (encrypted storage, secure file share)
- Validate checksums if provided by vendor

## Troubleshooting

### Issue: File Not Found During Build

**Error:**
```
File pentaho-server-ee-11.0.0.0-237.zip Not Found
```

**Solution:**
1. Verify file is in this directory
2. Check filename matches exactly (case-sensitive)
3. Ensure file is not corrupted:
   ```bash
   unzip -t pentaho-server-ee-11.0.0.0-237.zip
   ```

### Issue: Wrong Version

**Error:**
```
Version mismatch detected
```

**Solution:**
Ensure all files have matching version numbers:
```bash
# List all files with versions
ls -1 *.zip
```

### Issue: Corrupted Download

**Solution:**
```bash
# Re-download file
# Verify integrity
unzip -t pentaho-server-ee-11.0.0.0-237.zip

# Check file size matches expected
ls -lh pentaho-server-ee-11.0.0.0-237.zip
```

## Additional Resources

- [BUILD-PENTAHO-IMAGE.md](../../BUILD-PENTAHO-IMAGE.md) - Complete build guide
- [Dockerfile](../Dockerfile) - Image build configuration
- [Pentaho Documentation](https://help.hitachivantara.com/Documentation/Pentaho)

---

**Ready to build?**

Once files are in place:
```bash
cd ..
docker build -t pentaho/pentaho-server:11.0.0.0-237 .
```
