#!/bin/bash

# Function to log messages
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

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

# Check if crun runtime exists
if [ ! -f "/usr/local/bin/crun" ]; then
    log_message "ERROR: crun runtime not found at /usr/local/bin/crun"
    exit 1
fi

# Check if an argument is provided
if [ -z "$1" ]; then
        log_message "Error: Usage: $0 <cuda_device>"
        exit 1
fi

# Ccheck for non-negative CUDA device
case "$1" in
    ''|*[!0-9]*)
        log_message "ERROR: CUDA device must be a non-negative integer"
        exit 1
        ;;
esac

cuda_device=$1

# Load sensitive data from environment variables or exit if not set
CR_PAT="${CR_PAT:-}"
HF_TOKEN="${HF_TOKEN:-}"
CR_USER="${CR_USER:-}"
if [ -z "$CR_PAT" ] || [ -z "$HF_TOKEN" ] || [ -z "$CR_USER" ]; then
    log_message "ERROR: CR_USER, CR_PAT, and HF_TOKEN environment variables must be set"
    log_message "Example: export CR_USER='your_github_email' CR_PAT='your_github_token' HF_TOKEN='your_hf_token'"
    exit 1
fi

# Configuration variables
VERSION="2.3.3"
MODEL="meta-llama/Llama-3.3-70B-Instruct"
MAX_LENGTH=136192
ALLOC_TIMEOUT=6000
MEMORY="32g"
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

# Login to GitHub Container Registry
log_message "Logging into ghcr.io..."
echo "$CR_PAT" | podman login ghcr.io -u $CR_USER --password-stdin
if [ $? -ne 0 ]; then
    log_message "ERROR: Failed to login to ghcr.io"
    exit 1
fi

# Stop and remove existing container if it exists
if podman ps -a --filter "name=${NAME}" --format "{{.ID}}" | grep -q .; then
    log_message "Stopping and removing existing container ${NAME}..."
    podman stop "${NAME}" >/dev/null 2>&1
    podman rm "${NAME}" >/dev/null 2>&1
fi

# Run the Podman container
log_message "Starting Petals server on CUDA device ${cuda_device}..."
podman --runtime /usr/local/bin/crun run -d \
    --pull=newer --replace \
    -e CUDA_VISIBLE_DEVICES="${cuda_device}" \
    -p "${PORT}:${PORT}" \
    --network pasta \
    --ipc host \
    --device nvidia.com/gpu="${cuda_device}" \
    --volume "petals-cache_${cuda_device}:/cache" \
    --name "${NAME}" \
    --memory "${MEMORY}" \
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