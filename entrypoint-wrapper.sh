#!/bin/bash
# entrypoint-wrapper.sh - Wrapper script for Coder that auto-imports templates
# This script runs Coder server and automatically imports templates on first start

set -e

CODER_URL="${CODER_ACCESS_URL:-http://localhost:7080}"
TEMPLATE_DIR="/home/coder/templates"
TEMPLATE_FILE="docker-workspace.tf"
TEMPLATE_NAME="docker-workspace"
MAX_WAIT=300

# Function to check if user is authenticated
is_authenticated() {
    /opt/coder users list --output json 2>/dev/null | grep -q "\"username\"" || return 1
}

# Function to check if template already exists
template_exists() {
    /opt/coder templates list --output json 2>/dev/null | grep -q "\"name\":\"$TEMPLATE_NAME\"" || return 1
}

# Function to import template
import_template() {
    if [ ! -d "$TEMPLATE_DIR" ]; then
        echo "⚠ Template directory not found: $TEMPLATE_DIR"
        return 1
    fi
    
    if [ ! -f "$TEMPLATE_DIR/$TEMPLATE_FILE" ]; then
        echo "⚠ Template file not found: $TEMPLATE_DIR/$TEMPLATE_FILE"
        return 1
    fi
    
    # Check if any users exist (authentication required for template operations)
    if ! is_authenticated; then
        echo "⚠ No users found - template import requires authentication"
        echo "  Template will be available for manual import after creating your first admin user"
        echo "  Or run manually: docker exec coder /opt/coder templates push docker-workspace --directory /home/coder/templates --yes"
        return 1
    fi
    
    if template_exists; then
        echo "Template '$TEMPLATE_NAME' already exists. Updating..."
        if /opt/coder templates push "$TEMPLATE_NAME" \
            --directory "$TEMPLATE_DIR" \
            --yes 2>&1; then
            echo "✓ Template updated successfully"
            return 0
        else
            echo "⚠ Template update failed, trying create..."
            # Fall back to create if push fails (older Coder versions)
        fi
    fi
    
    echo "Importing template: $TEMPLATE_NAME"
    if /opt/coder templates create "$TEMPLATE_NAME" \
        --directory "$TEMPLATE_DIR" \
        --yes 2>&1; then
        echo "✓ Template imported successfully"
    else
        echo "⚠ Template import failed (may already exist or Coder not ready)"
        return 1
    fi
}

# Clean up stale PostgreSQL lock file if it exists
POSTGRES_DATA_DIR="/home/coder/.config/coderv2/postgres/data"
POSTGRES_PID_FILE="$POSTGRES_DATA_DIR/postmaster.pid"

if [ -f "$POSTGRES_PID_FILE" ]; then
    PID=$(head -n 1 "$POSTGRES_PID_FILE" 2>/dev/null || echo "")
    if [ -n "$PID" ]; then
        # Check if the process is actually running
        if ! kill -0 "$PID" 2>/dev/null; then
            echo "Removing stale PostgreSQL lock file (PID $PID not running)"
            rm -f "$POSTGRES_PID_FILE"
        else
            echo "Warning: PostgreSQL process $PID appears to be running"
        fi
    else
        # Empty or invalid PID file, remove it
        echo "Removing invalid PostgreSQL lock file"
        rm -f "$POSTGRES_PID_FILE"
    fi
fi

# Fix permissions for PostgreSQL data directory
if [ ! -d "$POSTGRES_DATA_DIR" ]; then
    mkdir -p "$POSTGRES_DATA_DIR"
    chown -R 99:100 "$POSTGRES_DATA_DIR"
fi
chmod 700 "$POSTGRES_DATA_DIR"

# Start Coder server in background
echo "=========================================="
echo "Starting Coder server..."
echo "=========================================="
/opt/coder server --http-address 0.0.0.0:7080 "$@" &

CODER_PID=$!

# Wait for Coder to be ready - check if server is listening on port
echo ""
echo "Waiting for Coder to initialize..."
WAIT_TIME=0
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    # Check if the server is listening on port 7080 or responding to health checks
    if netstat -tuln 2>/dev/null | grep -q ":7080 " || \
       ss -tuln 2>/dev/null | grep -q ":7080 " || \
       curl -s -f "http://127.0.0.1:7080/healthz" > /dev/null 2>&1 || \
       curl -s -f "http://127.0.0.1:7080/api/v2/buildinfo" > /dev/null 2>&1; then
        echo "✓ Coder is ready!"
        break
    fi
    sleep 5
    WAIT_TIME=$((WAIT_TIME + 5))
    if [ $((WAIT_TIME % 30)) -eq 0 ]; then
        echo "  Still waiting... (${WAIT_TIME}s/${MAX_WAIT}s)"
    fi
done

if [ $WAIT_TIME -ge $MAX_WAIT ]; then
    echo "⚠ Coder did not become ready after ${MAX_WAIT}s"
    echo "  Template import will be skipped"
    echo "  Coder server will continue running"
    echo "  Check logs for errors: docker logs coder"
else
    # Note: Permission fixes for workspace directories must be done on the host side
    # because the Coder container runs as UID 99 and cannot chown to 1000:1000
    # Workspace directories should be owned by 1000:1000 to match workspace containers
    
    if [ -f "$TEMPLATE_DIR/$TEMPLATE_FILE" ]; then
        echo ""
        echo "=========================================="
        echo "Auto-importing template..."
        echo "=========================================="
        export CODER_ACCESS_URL="$CODER_URL"
        import_template || true
        echo ""
    else
        echo "⚠ Template file not found at $TEMPLATE_DIR/$TEMPLATE_FILE"
        echo "  Skipping template import"
    fi
fi

echo "=========================================="
echo "Coder server is running"
echo "Access at: ${CODER_ACCESS_URL:-http://localhost:7080}"
echo "=========================================="
echo ""

# Wait for Coder process (keep container running)
wait $CODER_PID
