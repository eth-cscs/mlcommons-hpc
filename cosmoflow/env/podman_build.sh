#!/bin/bash

set -euo pipefail

set -x
cd $(dirname $0)

podman build --ulimit nofile=$(ulimit -n):$(ulimit -n) -t lukasgd/ngc-cosmoflow:24.04 .
enroot import -x mount -o /bret/scratch/cscs/lukasd/images/ngc-cosmoflow+24.04.sqsh podman://lukasgd/ngc-cosmoflow:24.04
set +x
