#!/bin/bash

port=8788
token='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'
version='2.3.3'
container='ghcr.io/reenvision-ai/petals:'$version
name='bootstrap'
CR_PAT='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'
external_ip=$(curl -s https://api.ipify.org)
echo $CR_PAT | podman login ghcr.io -u pgawestjones@gmail.com --password-stdin

set -x 
podman kill $name > /dev/null 2>&1

podman run -d \
    --pull=newer \
    --replace \
    --restart=always \
    --name $name \
    -p $port:$port \
    --volume bootstrap-cache:/cache \
    $container \
    python -m petals.cli.run_dht \
    --identity_path /cache/p2p.id \
    --use_auto_relay \
    --host_maddrs '/ip4/0.0.0.0/tcp/8788' \
    --public_ip $external_ip