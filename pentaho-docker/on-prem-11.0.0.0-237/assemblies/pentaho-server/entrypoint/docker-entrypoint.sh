#!/bin/bash
set -e

INSTALLATION_PATH=${INSTALLATION_PATH:-/opt/pentaho}
PENTAHO_SERVER=${INSTALLATION_PATH}/pentaho-server
PENTAHO_HOME=${PENTAHO_HOME:-/home/pentaho}

echo "============================================"
echo "Pentaho Server Docker Entrypoint"
echo "============================================"
echo "PENTAHO_VERSION: ${PENTAHO_VERSION}"
echo "INSTALLATION_PATH: ${INSTALLATION_PATH}"
echo "PENTAHO_HOME: ${PENTAHO_HOME}"
echo "============================================"

# Function to wait for database
wait_for_database() {
    echo "Waiting for PostgreSQL 17 database to be ready..."
    local max_attempts=60
    local attempt=1
    
    while [ "$attempt" -le "$max_attempts" ]; do
        if pg_isready -h repository -p 5432 -q 2>/dev/null; then
            echo "PostgreSQL database is ready!"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts - Database not ready, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    echo "WARNING: Database may not be ready after $max_attempts attempts"
    return 1
}

# Process software overrides from /docker-entrypoint-init
process_overrides() {
    local init_dir="/docker-entrypoint-init"
    
    if [ -d "$init_dir" ] && [ "$(ls -A $init_dir 2>/dev/null)" ]; then
        echo "Processing software overrides from $init_dir..."
        
        # Process directories in alphabetical order
        for dir in $(find "$init_dir" -mindepth 1 -maxdepth 1 -type d | sort); do
            if [ -d "$dir" ]; then
                echo "Processing override directory: $(basename $dir)"
                
                # Copy pentaho-solutions if exists
                if [ -d "$dir/pentaho-solutions" ]; then
                    echo "  Copying pentaho-solutions..."
                    cp -rv "$dir/pentaho-solutions/"* "${PENTAHO_SERVER}/pentaho-solutions/" 2>/dev/null || true
                fi
                
                # Copy tomcat if exists
                if [ -d "$dir/tomcat" ]; then
                    echo "  Copying tomcat..."
                    cp -rv "$dir/tomcat/"* "${PENTAHO_SERVER}/tomcat/" 2>/dev/null || true
                fi
            fi
        done
        
        echo "Software overrides processed successfully."
    else
        echo "No software overrides found in $init_dir"
    fi
}

# Copy home directory configurations
setup_home_config() {
    echo "Setting up home directory configurations..."
    
    # Copy .kettle if exists in mounted config
    if [ -d "${PENTAHO_HOME}/.kettle" ]; then
        echo "  .kettle configuration found"
    fi
    
    # Copy .pentaho if exists in mounted config
    if [ -d "${PENTAHO_HOME}/.pentaho" ]; then
        echo "  .pentaho configuration found"
    fi
}

# Main execution
echo "Starting initialization..."

# Wait for database if repository service exists
if getent hosts repository >/dev/null 2>&1; then
    wait_for_database
fi

# Process overrides
process_overrides

# Setup home configurations
setup_home_config

echo "============================================"
echo "Initialization complete. Starting Pentaho Server..."
echo "============================================"

# Execute the command passed to the container
exec "$@"
