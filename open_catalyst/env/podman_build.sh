#!/bin/bash

set -euo pipefail

cd $(dirname $0)

source ../../utils/podman_build.sh

set -x

podman_prepare_build_context .
podman build -t $USER/ngc-open_catalyst:24.03 .
enroot import -x mount -o $SCRATCH/images/ngc-open_catalyst+24.03.sqsh podman://$USER/ngc-open_catalyst:24.03

set +x
