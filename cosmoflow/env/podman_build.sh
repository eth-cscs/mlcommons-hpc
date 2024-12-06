#!/bin/bash

set -euo pipefail

cd $(dirname $0)

source ../../utils/podman_build.sh

set -x

podman_prepare_build_context .
podman build -t $USER/ngc-cosmoflow:24.04 .
enroot import -x mount -o $SCRATCH/images/ngc-cosmoflow+24.04.sqsh podman://$USER/ngc-cosmoflow:24.04

set +x
