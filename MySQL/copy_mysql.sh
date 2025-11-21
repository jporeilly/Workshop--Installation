#!/bin/bash
# Bash script to copy MySQL files
# Source: /home/$USER/Workshop--Installation/MySQL/*
# Destination: /home/$USER/MySQL

SOURCE_PATH="/home/$USER/Workshop--Installation/MySQL"
DEST_PATH="/home/$USER/MySQL"

# Check if source directory exists
if [ ! -d "$SOURCE_PATH" ]; then
    echo "Error: Source directory does not exist: $SOURCE_PATH" >&2
    exit 1
fi

# Create destination directory if it doesn't exist
if [ ! -d "$DEST_PATH" ]; then
    echo "Creating destination directory: $DEST_PATH"
    mkdir -p "$DEST_PATH"
fi

# Copy all files and subdirectories recursively
echo "Copying files from $SOURCE_PATH to $DEST_PATH..."

if cp -r "$SOURCE_PATH"/* "$DEST_PATH/" 2>/dev/null; then
    echo -e "\033[0;32mCopy operation completed successfully!\033[0m"
else
    echo "Error: An error occurred during the copy operation" >&2
    exit 1
fi