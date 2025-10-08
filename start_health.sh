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

VERSION='1.1.0'
CONTAINER="ghcr.io/reenvision-ai/health.reenvision.ai:${VERSION}"
PORT=5588
NAME='health'
MEMORY='16g'

# Stop and remove existing container if it exists
if podman ps -a --filter "name=${NAME}" --format "{{.ID}}" | grep -q .; then
    log_message "Stopping and removing existing container ${NAME}..."
    podman stop "${NAME}" >/dev/null 2>&1
    podman rm "${NAME}" >/dev/null 2>&1
fi

log_message "Starting Health Monitor..."
podman --runtime /usr/local/bin/crun \
    run -p "${PORT}:${PORT}" \
    --pull=newer \
    --replace \
    -m="${MEMORY}" \
    -d \
    --restart='unless-stopped' \
    --name "${NAME}" \
    "${CONTAINER}" \
    flask run --host=0.0.0.0 --port="${PORT}"

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to start Health Monitor"
    exit 1
fi

log_message "Health Monitor started successfully!"
log_message "Container name: ${NAME}"