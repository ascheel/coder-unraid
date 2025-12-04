#!/bin/bash
# entrypoint-wrapper.sh - Wrapper script for Coder that auto-imports templates
# This script runs Coder server and automatically imports templates on first start

set -e

CODER_URL="${CODER_ACCESS_URL:-http://localhost:7080}"
TEMPLATE_DIR="/home/coder/templates"
TEMPLATE_FILE="docker-workspace.tf"
TEMPLATE_NAME="docker-workspace-unraid"
MAX_WAIT=300

# Function to check if template already exists
template_exists() {
    /usr/local/bin/coder templates list --output json 2>/dev/null | grep -q "\"name\":\"$TEMPLATE_NAME\"" || return 1
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
    
    if template_exists; then
        echo "Template '$TEMPLATE_NAME' already exists. Skipping import."
        return 0
    fi
    
    echo "Importing template: $TEMPLATE_NAME"
    if /usr/local/bin/coder templates create "$TEMPLATE_NAME" \
        --directory "$TEMPLATE_DIR" \
        --yes 2>&1; then
        echo "✓ Template imported successfully"
    else
        echo "⚠ Template import failed (may already exist or Coder not ready)"
        return 1
    fi
}

# Start Coder server in background
echo "=========================================="
echo "Starting Coder server..."
echo "=========================================="
/usr/local/bin/coder server --address 0.0.0.0:7080 "$@" &

CODER_PID=$!

# Wait for Coder to be ready
echo ""
echo "Waiting for Coder to initialize..."
WAIT_TIME=0
while [ $WAIT_TIME -lt $MAX_WAIT ]; do
    if curl -s -f "${CODER_URL}/api/v2/users/me" > /dev/null 2>&1; then
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
elif [ -f "$TEMPLATE_DIR/$TEMPLATE_FILE" ]; then
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

echo "=========================================="
echo "Coder server is running"
echo "Access at: ${CODER_ACCESS_URL:-http://localhost:7080}"
echo "=========================================="
echo ""

# Wait for Coder process (keep container running)
wait $CODER_PID
