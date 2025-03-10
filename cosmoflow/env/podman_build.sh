#!/bin/bash

set -euo pipefail

cd $(dirname $0)

source ../../utils/podman_build.sh

if command -v nvidia-smi &> /dev/null; then

    : ${BASE_IMAGE:=nvcr.io/nvidia/tensorflow:24.04-tf2-py3}
    BASE_CONTAINER_REGISTRY=$(podman_utils_container_registry $BASE_IMAGE)
    BASE_TAG_SHORT=$(podman_utils_tag_short $BASE_IMAGE)

    set -x
    # podman_prepare_build_context .  # no longer needed with default compute mode
    podman_build_enroot_import ${BASE_CONTAINER_REGISTRY}-cosmoflow:${BASE_TAG_SHORT} -f Dockerfile --build-arg BASE_IMAGE=${BASE_IMAGE} .
    #podman_build_enroot_import ${BASE_CONTAINER_REGISTRY}-cosmoflow:${BASE_TAG_SHORT}-libfabric -f Dockerfile-libfabric --build-arg BASE_IMAGE=${BASE_IMAGE} .
    set +x

elif command -v rocm-smi &> /dev/null; then

    : ${BASE_IMAGE:=docker.io/rocm/tensorflow:rocm6.3.3-py3.10-tf2.15-dev}
    # : ${BASE_IMAGE:=docker.io/rocm/tensorflow:rocm6.3.3-py3.12-tf2.16-dev}
    # : ${BASE_IMAGE:=docker.io/rocm/tensorflow:rocm6.3.3-py3.12-tf2.17-dev}

    BASE_CONTAINER_REGISTRY=$(podman_utils_container_registry $BASE_IMAGE)
    BASE_TAG_SHORT=$(podman_utils_tag_short $BASE_IMAGE)

    set -x
    podman_build_enroot_import ${BASE_CONTAINER_REGISTRY}-cosmoflow:${BASE_TAG_SHORT} -f Dockerfile-rocm --build-arg BASE_IMAGE=${BASE_IMAGE} .
    #podman_build_enroot_import ${BASE_CONTAINER_REGISTRY}-cosmoflow:${BASE_TAG_SHORT}-libfabric -f Dockerfile-rocm-libfabric --build-arg BASE_IMAGE=${BASE_IMAGE} .
    set +x

else
    echo "Error: No CPU-only image available."
    exit 1
fi
