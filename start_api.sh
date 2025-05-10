#!/bin/bash

export CR_PAT='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'
echo $CR_PAT | podman login ghcr.io -u pgawestjones@gmail.com --password-stdin
API_VERSION='0.3.6'
set -x
port=5000
name=api
gpu=0
container='ghcr.io/reenvision-ai/petals-api:'$API_VERSION 

podman kill $name > /dev/null 2>&1

podman --runtime /usr/local/bin/crun run \
    --pull newer \
    --replace \
    -p $port:$port \
    --ipc host \
    --device nvidia.com/gpu=$gpu \
    --volume api-cache:/cache \
    --restart='unless-stopped' \
    --name $name \
    $container