#!/bin/bash

export CR_PAT='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'
echo $CR_PAT | podman login ghcr.io -u pgawestjones@gmail.com --password-stdin
set -x
version='1.0.5'
container='ghcr.io/reenvision-ai/health.reenvision.ai:'$version
port=5588
name='health'

podman kill $name > /dev/null 2>&1

podman --runtime /usr/local/bin/crun \
    run -p $port:$port \
    --pull=newer \
    --replace \
    -m=16g \
    -d \
    --restart='unless-stopped' \
    --name $name \
    $container \
    flask run --host=0.0.0.0 --port=$port