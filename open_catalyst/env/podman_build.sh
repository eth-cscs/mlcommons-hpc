#!/bin/bash

set -euo pipefail

set -x
cd $(dirname $0)

podman build --ulimit nofile=$(ulimit -n):$(ulimit -n) -t lukasgd/ngc-open_catalyst:24.03 .
enroot import -x mount -o /capstor/scratch/cscs/lukasd/images/ngc-open_catalyst+24.03.sqsh podman://lukasgd/ngc-open_catalyst:24.03
set +x
