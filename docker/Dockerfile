# Dockerfile for Coder with automatic template import
# This extends the official Coder image and adds automatic template import functionality
#
# Build arguments:
#   CODER_VERSION - Version of Coder to use (default: latest)
#   Example: docker build --build-arg CODER_VERSION=v2.28.5 -t coder-unraid:v2.28.5 .

ARG CODER_VERSION=latest
FROM ghcr.io/coder/coder:${CODER_VERSION}

USER root

# Set working directory
WORKDIR /home/coder

# Copy template files
COPY docker-workspace.tf /home/coder/templates/docker-workspace.tf
COPY import-template.sh /home/coder/templates/import-template.sh

# Copy entrypoint wrapper
COPY entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh

# Create user entry for UID 99:100 (unRAID nobody:users) - required for PostgreSQL initdb
# This image is Alpine-based, so use adduser/addgroup (not useradd/groupadd).
# PostgreSQL's initdb needs a valid passwd entry for the *effective UID*.
RUN if ! getent passwd 99 >/dev/null 2>&1; then \
      # Ensure group 'users' exists at GID 100 (it typically does on Alpine) \
      getent group 100 >/dev/null 2>&1 || addgroup -g 100 users || true; \
      # Create a user that maps to UID 99 / GID 100; name can be arbitrary \
      adduser -D -u 99 -G users -h /home/coder -s /bin/bash unraid || true; \
    fi

# Make scripts executable and fix ownership
# Change ownership to UID 99:100 (unRAID nobody:users) to match compose.yaml user setting
RUN ls -ld /home/coder/templates /usr/local/bin && \
    chmod +x /home/coder/templates/import-template.sh && \
    chmod +x /usr/local/bin/entrypoint-wrapper.sh && \
    chown -R 99:100 /home/coder && \
    chown 99:100 /usr/local/bin/entrypoint-wrapper.sh && \
    chmod 755 /home/coder && \
    mkdir -p /home/coder/.cache && \
    chown -R 99:100 /home/coder/.cache

# Note: We don't switch to USER here because compose.yaml overrides with user: "99:100"
# The container will run as UID 99:100 (unRAID nobody:users)

# Set the wrapper as the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]

# Default command (can be overridden)
CMD ["--http-address", "0.0.0.0:7080"]
