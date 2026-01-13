#!/bin/bash
# =============================================================================
# Pentaho Server Docker Entrypoint Script
# =============================================================================
#
# Location: docker/entrypoint/docker-entrypoint.sh
#
# This script runs when the Pentaho Server container starts. It performs:
#   1. JVM configuration via CATALINA_OPTS
#   2. Configuration overlay from softwareOverride directories
#   3. Optional license installation
#   4. Execution of any custom entrypoint scripts
#   5. Starting the Pentaho Server
#
# Environment Variables:
#   PENTAHO_VERSION     - Pentaho version (set in Dockerfile)
#   PENTAHO_SERVER_PATH - Path to Pentaho installation (set in Dockerfile)
#   INSTALLATION_PATH   - Root installation path (set in Dockerfile)
#   LICENSE_URL         - Optional URL to download EE license file
#
# Configuration Overlay:
#   Files in /docker-entrypoint-init (mounted from softwareOverride/)
#   are copied to $PENTAHO_SERVER_PATH in alphabetical order by directory.
#   This allows customizing Pentaho configuration without modifying the
#   base installation.
#
# See Also:
#   - softwareOverride/README.md - Configuration override documentation
#   - ARCHITECTURE.md - System architecture
#
# =============================================================================

# Configure JVM options for Tomcat
# - NODE_NAME: Container hostname for cluster identification
# - headless: Required for server environments without display
export CATALINA_OPTS="$CATALINA_OPTS -DNODE_NAME=$(hostname) -Djava.awt.headless=true"

# =============================================================================
# License Configuration
# =============================================================================
# Check if LICENSE_URL environment variable is set
# Enterprise Edition features require a valid license
if [ -z "$LICENSE_URL" ]; then
	echo '$LICENSE_URL is not set - running without EE license'
fi

# =============================================================================
# Configuration Overlay Processing
# =============================================================================
# Process softwareOverride directories in alphabetical order:
#   1_drivers/    - JDBC drivers (MySQL connector, etc.)
#   2_repository/ - Database configuration (Hibernate, JackRabbit, Quartz)
#   3_security/   - Authentication settings (Spring Security)
#   4_others/     - Tomcat config, defaults, and miscellaneous
#
# The alphabetical ordering ensures drivers are available before
# repository configuration is applied.

echo "Pentaho Server Version: $PENTAHO_VERSION"
echo "Processing configuration overlays from /docker-entrypoint-init..."

for dir in $(find /docker-entrypoint-init/ -mindepth 1 -maxdepth 1 -type d | sort); do
	# Skip directories containing a .ignore file
	# This allows temporarily disabling specific configurations
	if [ -f "$dir/.ignore" ]; then
		echo "Skipping $dir (contains .ignore file)"
		continue
	fi

	# Count and copy files to Pentaho installation
	file_count=$(find "$dir" -type f -print | wc -l)
	echo "Copying $file_count files from $dir to $PENTAHO_SERVER_PATH"
	cp -a "$dir/." "$PENTAHO_SERVER_PATH"
done

echo "Configuration overlay complete."

# =============================================================================
# Custom Entrypoint Extension
# =============================================================================
# If extra-entrypoint.sh exists, execute it
# This allows users to add custom initialization logic
if [ -f "$PENTAHO_SERVER_PATH/extra-entrypoint.sh" ]; then
	echo "Executing custom entrypoint: extra-entrypoint.sh"
	. "$PENTAHO_SERVER_PATH/extra-entrypoint.sh"
fi

# =============================================================================
# License Installation
# =============================================================================
# Install EE license if LICENSE_URL is provided and license not already installed
# License file is stored in ~/.pentaho/.elmLicInfo.plt
if [ ! -f ~/.pentaho/.elmLicInfo.plt ] && [ -n "$LICENSE_URL" ]; then
	echo "Installing Enterprise Edition license from: $LICENSE_URL"
	$INSTALLATION_PATH/license-installer/install_license.sh "$LICENSE_URL"
fi

# =============================================================================
# Start Pentaho Server
# =============================================================================
# Execute the command passed to the container (default: ./start-pentaho.sh)
echo "Starting Pentaho Server..."
exec "$@"
