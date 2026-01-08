#!/bin/bash
# Fix permissions on workspace directories
# Run this periodically or after workspace creation

WORKSPACES_DIR="/mnt/user/appdata/coder/workspaces"
if [ -d "$WORKSPACES_DIR" ]; then
    # Fix any directories owned by root (should be 1000:1000 for workspace containers)
    # Use numeric UID/GID to avoid user name issues
    find "$WORKSPACES_DIR" -maxdepth 1 -type d ! -name "." ! -name "shared" \
        -exec sh -c 'OWNER=$(stat -c "%u" "$1" 2>/dev/null || echo "0"); if [ "$OWNER" = "0" ] || [ "$OWNER" != "1000" ]; then chown -R 1000:1000 "$1" 2>/dev/null; fi' _ {} \;
    find "$WORKSPACES_DIR" -maxdepth 1 -type d -exec chmod 755 {} \; 2>/dev/null
    echo "Fixed workspace permissions"
fi
