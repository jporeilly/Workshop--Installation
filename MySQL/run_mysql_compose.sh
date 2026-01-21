#!/bin/bash
# Bash script to run docker-compose from MySQL folder

WORKING_DIR="/home/$USER/MySQL"

# Check if the directory exists
if [ ! -d "$WORKING_DIR" ]; then
    echo "Error: Directory does not exist: $WORKING_DIR" >&2
    exit 1
fi

# Check if docker-compose.yml exists in the directory
COMPOSE_FILE="$WORKING_DIR/docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: docker-compose.yml not found in: $WORKING_DIR" >&2
    exit 1
fi

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker and ensure it's running." >&2
    exit 1
fi

DOCKER_VERSION=$(docker --version 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error: Docker is not running properly." >&2
    exit 1
fi
echo "Docker found: $DOCKER_VERSION"

# Check if docker-compose is available (try both syntaxes)
COMPOSE_COMMAND=""
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version 2>/dev/null)
    COMPOSE_COMMAND="docker compose"
    echo "Docker Compose found: $COMPOSE_VERSION"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version 2>/dev/null)
    if [ $? -eq 0 ]; then
        COMPOSE_COMMAND="docker-compose"
        echo "Docker Compose found: $COMPOSE_VERSION"
    fi
fi

if [ -z "$COMPOSE_COMMAND" ]; then
    echo "Error: Docker Compose is not installed or not available." >&2
    exit 1
fi

# Save current directory
ORIGINAL_DIR=$(pwd)

# Change to working directory and run docker-compose
echo "Changing to directory: $WORKING_DIR"
cd "$WORKING_DIR" || {
    echo "Error: Failed to change to directory: $WORKING_DIR" >&2
    exit 1
}

echo "Running $COMPOSE_COMMAND up -d..."

# Run docker-compose up in detached mode
$COMPOSE_COMMAND up -d

# Check exit status
if [ $? -eq 0 ]; then
    echo -e "\033[0;32mDocker Compose started successfully!\033[0m"
    echo "You can check the status with: $COMPOSE_COMMAND ps"
    echo "To view logs, use: $COMPOSE_COMMAND logs"
    echo "To stop the services, use: $COMPOSE_COMMAND down"
    EXIT_CODE=0
else
    echo "Error: Docker Compose failed to start. Exit code: $?" >&2
    EXIT_CODE=1
fi

# Return to original directory
cd "$ORIGINAL_DIR"

exit $EXIT_CODE