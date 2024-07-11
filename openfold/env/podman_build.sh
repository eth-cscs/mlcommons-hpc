#!/bin/bash

set -euo pipefail

set -x
cd $(dirname $0)

#podman build  -t ahernnde/ngc-openfold:24.03 .
enroot import -x mount -o /capstor/scratch/cscs/ahernnde/container-image/openfold/ngc-openfold-24.03.sqsh podman://ahernnde/ngc-openfold:24.03
set +x
