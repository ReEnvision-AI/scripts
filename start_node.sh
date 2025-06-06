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
if [ ! -f "$RUNTIME" ]; then
    log_message "ERROR: OCI runtime not found at $RUNTIME"
    exit 1
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
VERSION="${VERSION:-${2:-2.3.5}}"
log_message "Using version: ${VERSION}"

# Display model selection menu
echo "Please select a model:"
for i in "${!MODELS[@]}"; do
    echo "$((i+1)). ${MODELS[i]}"
done

# Get user selection
while true; do
    read -p "Enter the number of your choice (1-${#MODELS[@]}): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#MODELS[@]}" ]; then
        MODEL=${MODELS[$((choice-1))]}
        break
    else
        echo "Invalid choice. Please enter a number between 1 and ${#MODELS[@]}."
    fi
done

MAX_LENGTH="${MAX_LENGTH:-136192}"
ALLOC_TIMEOUT="${ALLOC_TIMEOUT:-6000}"
QUANT_TYPE="${QUANT_TYPE:-nf4}"
ATTN_CACHE_TOKENS="${ATTN_CACHE_TOKENS:-128000}"
CONTAINER="ghcr.io/reenvision-ai/petals:${VERSION}"
NAME="node_cuda_${cuda_device}"
MAX_CHUNK_SIZE_BYTES="${MAX_CHUNK_SIZE_BYTES:-1073741824}"

BASE_PORT="${BASE_PORT:-58527}"
DEFAULT_PORT=$((BASE_PORT + cuda_device))
echo -e "\n"
read -p "Enter port number (press Enter for default value of ${DEFAULT_PORT}): " user_port
if [ -z "$user_port" ]; then
    PORT="${DEFAULT_PORT}"
else
    # Check if input is a valid number
    if ! [[ "$user_port" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be a number."
        exit 1
    fi
    # Check if port is within valid range (1-65535)
    if [ "$user_port" -lt 1 ] || [ "$user_port" -gt 65535 ]; then
        echo "Error: Port must be between 1 and 65535."
        exit 1
    fi
    PORT=$user_port
fi
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
if podman ps -q --filter "name=${NAME}" | grep -q .; then
    log_message "Stopping running container ${NAME}..."
    podman stop "${NAME}" >/dev/null 2>&1
fi
if podman ps -a -q --filter "name=${NAME}" | grep -q .; then
    log_message "Removing existing container ${NAME}..."
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
    --max_chunk_size_bytes "${MAX_CHUNK_SIZE_BYTES}" \
    --throughput eval \
    "${MODEL}"

if [ $? -ne 0 ] || [ "$(podman inspect -f '{{.State.Running}}' "${NAME}" 2>/dev/null)" != "true" ]; then
    log_message "ERROR: Container ${NAME} failed to start"
    exit 1
fi

log_message "Petals server started successfully!"
log_message "Container name: ${NAME}"
echo -e "\n"
read -p "Do you want to start viewing the logs for ${NAME}? (y/N): " logs
if [[ "$logs" =~ ^[Yy]$ ]]; then
    podman logs -f "${NAME}"
else
    log_message "To view logs later, run: podman logs -f ${NAME}"
fi