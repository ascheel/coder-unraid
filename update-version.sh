#!/bin/bash
# update-version.sh - Update template to match a specific Coder version
#
# Usage: ./update-version.sh v2.9.0
#        ./update-version.sh v2.9.0 "Fixed workspace creation bug"

set -e

NEW_VERSION=$1
COMMIT_MSG=$2

if [ -z "$NEW_VERSION" ]; then
  echo "Usage: $0 <version> [commit-message]"
  echo "Example: $0 v2.9.0"
  echo "Example: $0 v2.9.0 'Fixed workspace creation bug'"
  exit 1
fi

# Validate version format (basic check)
if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: Version must be in format vX.Y.Z (e.g., v2.9.0)"
  exit 1
fi

# Extract version number without 'v' prefix for some uses
VERSION_NUM=${NEW_VERSION#v}

echo "Updating template to Coder ${NEW_VERSION}..."

# Update coder.xml
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  sed -i '' "s|ghcr.io/coder/coder:v[0-9.]*|ghcr.io/coder/coder:${NEW_VERSION}|g" coder.xml
else
  # Linux
  sed -i "s|ghcr.io/coder/coder:v[0-9.]*|ghcr.io/coder/coder:${NEW_VERSION}|g" coder.xml
fi

echo "✓ Updated coder.xml"

# Update docker-compose.yml if it exists
if [ -f "docker-compose.yml" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s|ghcr.io/coder/coder:.*|ghcr.io/coder/coder:${NEW_VERSION}|g" docker-compose.yml
  else
    sed -i "s|ghcr.io/coder/coder:.*|ghcr.io/coder/coder:${NEW_VERSION}|g" docker-compose.yml
  fi
  echo "✓ Updated docker-compose.yml"
fi

# Show what changed
echo ""
echo "Changes made:"
git diff coder.xml docker-compose.yml 2>/dev/null || echo "  - Repository updated to ${NEW_VERSION}"

echo ""
echo "Next steps:"
echo "1. Review the changes above"
echo "2. Test the new version locally:"
echo "   docker run --rm -it ghcr.io/coder/coder:${NEW_VERSION}"
echo "3. Test the template on unRAID"
echo "4. Update CHANGELOG.md if needed"
echo "5. Commit changes:"
if [ -z "$COMMIT_MSG" ]; then
  echo "   git add coder.xml docker-compose.yml"
  echo "   git commit -m \"Update to Coder ${NEW_VERSION}\""
else
  echo "   git add coder.xml docker-compose.yml"
  echo "   git commit -m \"Update to Coder ${NEW_VERSION} - ${COMMIT_MSG}\""
fi
echo "6. Create tag: git tag -a ${NEW_VERSION} -m \"Coder ${NEW_VERSION}\""
echo "7. Push: git push origin main && git push origin ${NEW_VERSION}"
echo "8. Create GitHub release for ${NEW_VERSION}"

