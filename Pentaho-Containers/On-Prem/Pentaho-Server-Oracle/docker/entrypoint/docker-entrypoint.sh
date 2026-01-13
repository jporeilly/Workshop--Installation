#!/bin/bash
# =============================================================================
# Pentaho Server Docker Entrypoint Script (Oracle Repository)
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
# =============================================================================

# Configure JVM options for Tomcat
export CATALINA_OPTS="$CATALINA_OPTS -DNODE_NAME=$(hostname) -Djava.awt.headless=true"

# =============================================================================
# License Configuration
# =============================================================================
if [ -z "$LICENSE_URL" ]; then
	echo '$LICENSE_URL is not set - running without EE license'
fi

# =============================================================================
# Configuration Overlay Processing
# =============================================================================
# Process softwareOverride directories in alphabetical order:
#   1_drivers/    - JDBC drivers (Oracle JDBC driver)
#   2_repository/ - Database configuration (Hibernate, JackRabbit, Quartz)
#   3_security/   - Authentication settings (Spring Security)
#   4_others/     - Tomcat config, defaults, and miscellaneous

echo "Pentaho Server Version: $PENTAHO_VERSION"
echo "Processing configuration overlays from /docker-entrypoint-init..."

for dir in $(find /docker-entrypoint-init/ -mindepth 1 -maxdepth 1 -type d | sort); do
	# Skip directories containing a .ignore file
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
if [ -f "$PENTAHO_SERVER_PATH/extra-entrypoint.sh" ]; then
	echo "Executing custom entrypoint: extra-entrypoint.sh"
	. "$PENTAHO_SERVER_PATH/extra-entrypoint.sh"
fi

# =============================================================================
# License Installation
# =============================================================================
if [ ! -f ~/.pentaho/.elmLicInfo.plt ] && [ -n "$LICENSE_URL" ]; then
	echo "Installing Enterprise Edition license from: $LICENSE_URL"
	$INSTALLATION_PATH/license-installer/install_license.sh "$LICENSE_URL"
fi

# =============================================================================
# Start Pentaho Server
# =============================================================================
echo "Starting Pentaho Server..."
exec "$@"
