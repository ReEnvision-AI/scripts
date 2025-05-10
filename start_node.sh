#!/bin/bash

# Check if an argument is provided
if [ -z "$1" ]; then
        echo "Usage: $0 <cuda_device>"
        exit 1
fi

# Set the CUDA device from the first argument
cuda_device=$1

# Find a free port using Python and assign it to the 'port' variable
# port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
port=$((58527 + $1))
echo "PORT is $port"

CR_PAT='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'
echo $CR_PAT | podman login ghcr.io -u pgawestjones@gmail.com --password-stdin
version='2.3.3'

token='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'
model='meta-llama/Llama-3.3-70B-Instruct'
nemotron_model='nvidia/Lllama-3.1-Nemotron-Nano-8B-v1'
max_length=136192
alloc_timeout=6000
name='node_cuda_'$cuda_device
memory='32g'
container='ghcr.io/reenvision-ai/petals:'$version
external_ip=$(curl -s https://api.ipify.org)

podman kill $name > /dev/null 2>&1

podman --runtime /usr/local/bin/crun run -d \
    --pull=newer --replace \
    -e CUDA_VISIBLE_DEVICES=$cuda_device \
    -p $port:$port \
    --network pasta \
    --ipc host \
    --device nvidia.com/gpu=$cuda_device \
    --volume petals-cache_$1:/cache \
    --name $name \
    $container \
    python -m petals.cli.run_server \
    --public_ip $external_ip \
    --port $port \
    --inference_max_length $max_length \
    --token $token \
    --max_alloc_timeout $alloc_timeout \
    --quant_type 'nf4' \
    --attn_cache_tokens 128000 \
    --throughput eval \
    $model