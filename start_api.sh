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

login_to_github

VERSION='0.4.2'
# Check if version is provided as argument
if [ ! -z "$1" ]; then
    VERSION="$1"
    log_message "Using provided version: ${VERSION}"
else
    log_message "Using default version: ${VERSION}"
fi

PORT=5000
NAME=api
GPU=0
CONTAINER="ghcr.io/reenvision-ai/agentgrid-api:${VERSION}"

# Stop and remove existing container if it exists
if podman ps -a --filter "name=${NAME}" --format "{{.ID}}" | grep -q .; then
    log_message "Stopping and removing existing container ${NAME}..."
    podman stop "${NAME}" >/dev/null 2>&1
    podman rm "${NAME}" >/dev/null 2>&1
fi

# Run the Podman container
log_message "Starting API server ..."
podman --runtime /usr/local/bin/crun run -d \
    --pull newer \
    --replace \
    -e HF_HUB_DISABLE_XET=1 \
    -p "${PORT}:${PORT}" \
    --ipc host \
    --device "nvidia.com/gpu=${GPU}" \
    --volume api-cache:/cache \
    --restart='unless-stopped' \
    --name "${NAME}" \
    "${CONTAINER}"

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to start API server"
    exit 1
fi

log_message "API server started successfully!"
log_message "Container name: ${NAME}"