#!/bin/bash

set -euo pipefail

cd $(dirname $0)

source ../../utils/podman_build.sh

if nvidia-smi &> /dev/null; then

    : ${BASE_IMAGE:=nvcr.io/nvidia/pytorch:24.03-py3}
    BASE_CONTAINER_REGISTRY=$(podman_utils_container_registry $BASE_IMAGE)
    BASE_TAG_SHORT=$(podman_utils_tag_short $BASE_IMAGE)

    set -x
    # podman_prepare_build_context .  # no longer needed with default compute mode
    podman_build_enroot_import ${BASE_CONTAINER_REGISTRY}-openfold:${BASE_TAG_SHORT} -f Dockerfile --build-arg BASE_IMAGE=${BASE_IMAGE} .
    set +x

elif rocm-smi &> /dev/null; then

    # : ${BASE_IMAGE:=docker.io/rocm/pytorch:rocm7.1.1_ubuntu24.04_py3.12_pytorch_release_2.9.1}
    : ${BASE_IMAGE:=docker.io/rocm/pytorch:rocm6.4.4_ubuntu24.04_py3.12_pytorch_release_2.7.1}
    # : ${BASE_IMAGE:=docker.io/rocm/pytorch:rocm6.3.3_ubuntu24.04_py3.12_pytorch_release_2.4.0}
    BASE_CONTAINER_REGISTRY=$(podman_utils_container_registry $BASE_IMAGE)
    BASE_TAG_SHORT=$(podman_utils_tag_short $BASE_IMAGE)

    set -x
    podman_build_enroot_import ${BASE_CONTAINER_REGISTRY}-openfold:${BASE_TAG_SHORT} -f Dockerfile-rocm --build-arg BASE_IMAGE=${BASE_IMAGE} .
    set +x
else
    echo "Error: No CPU-only image available."
    exit 1
fi

