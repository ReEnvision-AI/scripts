#!/bin/bash

# Source the logging function
if [ -f "$(dirname "$0")/logging.sh" ]; then
    . "$(dirname "$0")/logging.sh"
else
    echo "ERROR: logging.sh not found in script directory"
    exit 1
fi

# Source the github login function
if [ -f "$(dirname "$0")/github_login.sh" ]; then
    . "$(dirname "$0")/github_login.sh"
else
    echo "ERROR: github_login.sh not found in script directory"
    exit 1
fi

# Check if crun runtime exists
if [ ! -f "/usr/local/bin/crun" ]; then
    log_message "ERROR: crun runtime not found at /usr/local/bin/crun"
    exit 1
fi

login_to_github

PORT="8788"

VERSION="${BOOTSTRAP_VERSION:-${1:-1.4.1-bootstrap}}"
log_message "Using version: ${VERSION}"

IDENTITY_FILENAME="${2:-identity_0.key}"
log_message "Using identity key: ${IDENTITY_FILENAME}"

CONTAINER="ghcr.io/reenvision-ai/agent-grid:${VERSION}"
NAME='bootstrap'
# Get external IP
EXTERNAL_IP=$(curl -s --connect-timeout 5 https://api.ipify.org)
if [ -z "$EXTERNAL_IP" ]; then
    log_message "ERROR: Failed to fetch external IP"
    exit 1
fi
log_message "External IP: $EXTERNAL_IP"

# Stop and remove existing container if it exists
if podman ps -a --filter "name=${NAME}" --format "{{.ID}}" | grep -q .; then
    log_message "Stopping and removing existing container ${NAME}..."
    podman stop "${NAME}" >/dev/null 2>&1
    podman rm "${NAME}" >/dev/null 2>&1
fi

log_message "Starting Bootstrap Server..."
podman --runtime /usr/local/bin/crun run -d \
    --pull=newer \
    --replace \
    --restart=always \
    --name "${NAME}" \
    --volume bootstrap-cache:/cache \
    --network host \
    --ipc host \
    $CONTAINER \
    python -m agentgrid.cli.run_dht \
    --identity_path "/app/identity_files/${IDENTITY_FILENAME}"\
    --use_auto_relay \
    --host_maddrs "/ip4/0.0.0.0/tcp/${PORT}" \
    --announce_maddrs "/ip4/${EXTERNAL_IP}/tcp/${PORT}"

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to start Bootstrap server"
    exit 1
fi

log_message "Agent Grid Bootstrap server started successfully!"
log_message "Container name: ${NAME}"