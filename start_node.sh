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

# Check if models file exists
if [ -f "$(dirname "$0")/models" ]; then
    . "$(dirname "$0")/models"
else
    echo "Error: models file not found. Please create a models file with a list of models."
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required commands
for cmd in podman curl python3; do
    if ! command_exists "$cmd"; then
        log_message "ERROR: $cmd is required but not installed."
        exit 1
    fi
done

RUNTIME="/usr/local/bin/crun"
# Check if crun runtime exists
if [ ! -f "${RUNTIME}" ]; then
    #log_message "WARN: crun runtime not found at /usr/local/bin/crun"
    #exit 1
    RUNTIME="/usr/bin/crun"
    if [ ! -f "${RUNTIME}" ]; then
    log_message "WARNING: crun runtime not found at /usr/local/bin/crun nor /usr/bin/crun"
    exit 1
fi
fi


# Check if an argument is provided
if [ -z "$1" ]; then
    log_message "ERROR: Usage: $0 <cuda_device>"
    exit 1
fi

# Check for non-negative CUDA device
case "$1" in
    ''|*[!0-9]*)
        log_message "ERROR: CUDA device must be a non-negative integer"
        exit 1
        ;;
esac

cuda_device=$1


# Configuration variables
VERSION="2.3.4"
# Check if version is provided as argument
if [ ! -z "$2" ]; then
    VERSION="$2"
    log_message "Using provided version: ${VERSION}"
else
    log_message "Using default version: ${VERSION}"
fi

# Display model selection menu
echo "Please select a model:"
for i in "${!MODELS[@]}"; do
    echo "$((i+1)). ${MODELS[i]}"
done

# Get user selection
while true; do
    read -p "Enter the number of your choice (1-${#MODELS[@]}): " choice
    if [[ "$choice" =~ ^[1-2]$ ]]; then
        MODEL=${MODELS[$((choice-1))]}
        break
    else
        echo "Invalid choice. Please enter a number between 1 and ${#MODELS[@]}."
    fi
done

MAX_LENGTH=136192
ALLOC_TIMEOUT=6000
QUANT_TYPE="nf4"
ATTN_CACHE_TOKENS=128000
CONTAINER="ghcr.io/reenvision-ai/petals:${VERSION}"
NAME="node_cuda_${cuda_device}"

PORT=$((58527 + $1))
log_message "Assigned port: $PORT"

# Get external IP
EXTERNAL_IP=$(curl -s --connect-timeout 5 https://api.ipify.org)
if [ -z "$EXTERNAL_IP" ]; then
    log_message "ERROR: Failed to fetch external IP"
    exit 1
fi
log_message "External IP: $EXTERNAL_IP"

# Login to github to pull the container
login_to_github

# Stop and remove existing container if it exists
if podman ps -a --filter "name=${NAME}" --format "{{.ID}}" | grep -q .; then
    log_message "Stopping and removing existing container ${NAME}..."
    podman stop "${NAME}" >/dev/null 2>&1
    podman rm "${NAME}" >/dev/null 2>&1
fi

# Run the Podman container
log_message "Starting Petals server on CUDA device ${cuda_device}..."
podman --runtime "${RUNTIME}" run -d \
    --pull=newer --replace \
    -e CUDA_VISIBLE_DEVICES="${cuda_device}" \
    --network host \
    --ipc host \
    --device "nvidia.com/gpu=all" \
    --volume "petals-cache_${cuda_device}:/cache" \
    --name "${NAME}" \
    "${CONTAINER}" \
    python -m petals.cli.run_server \
    --public_ip "${EXTERNAL_IP}" \
    --port "${PORT}" \
    --inference_max_length "${MAX_LENGTH}" \
    --token "${HF_TOKEN}" \
    --max_alloc_timeout "${ALLOC_TIMEOUT}" \
    --quant_type "${QUANT_TYPE}" \
    --attn_cache_tokens "${ATTN_CACHE_TOKENS}" \
    --throughput eval \
    "${MODEL}"

if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to start Petals server"
    exit 1
fi

log_message "Petals server started successfully!"
log_message "Container name: ${NAME}"