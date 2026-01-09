#!/bin/bash
# rebuild.sh - Rebuild the Coder Docker image and restart the container
# This ensures template changes are baked into the image

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CODER_VERSION="${1:-v2.28.6}"
IMAGE_NAME="coder:${CODER_VERSION}"

echo "=========================================="
echo "Rebuilding Coder Docker Image"
echo "=========================================="
echo "Version: $CODER_VERSION"
echo "Image: $IMAGE_NAME"
echo ""

# Build the image with --no-cache to ensure all changes are picked up
echo "Building Docker image (this may take a few minutes)..."
docker build --no-cache \
    -t "$IMAGE_NAME" \
    --build-arg CODER_VERSION="$CODER_VERSION" \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Image built successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Restart the container in Dockge (or run: docker restart coder)"
    echo "2. The template will be automatically updated when the container starts"
    echo ""
    echo "To restart now, run: docker restart coder"
else
    echo ""
    echo "✗ Build failed!"
    exit 1
fi
