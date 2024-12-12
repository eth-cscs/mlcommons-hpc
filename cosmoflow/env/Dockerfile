FROM nvcr.io/nvidia/tensorflow:24.04-tf2-py3

RUN apt-get update \
  && apt-get install -yqq --no-install-recommends openssh-server \
  && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/sshd

RUN python -m pip install --no-cache-dir -U pip

RUN pip install --no-cache-dir pandas wandb

# Install MLPerf-logging
RUN pip install --no-cache-dir "git+https://github.com/mlcommons/logging.git"

RUN pip uninstall -y horovod

ENV MPICH_VER=4.2.1

RUN wget -q http://www.mpich.org/static/downloads/${MPICH_VER}/mpich-${MPICH_VER}.tar.gz \
    && tar xf mpich-${MPICH_VER}.tar.gz \
    && cd mpich-${MPICH_VER} \
    && ./configure --disable-fortran --with-device=ch3:sock -prefix=/usr \
    && make -j 3 \ 
    && make install \
    && cd .. \
    && rm -rf mpich-${MPICH_VER} \
    && rm mpich-${MPICH_VER}.tar.gz

ARG HOROVOD_VERSION=0.28.1
RUN ldconfig /usr/local/cuda/targets/sbsa-linux/lib/stubs && \
    MPI_HOME=/usr HOROVOD_GPU_OPERATIONS=NCCL HOROVOD_WITH_TENSORFLOW=1 HOROVOD_WITH_MPI=1 \
    pip install --no-cache-dir -v git+https://github.com/horovod/horovod.git@v${HOROVOD_VERSION} && \
    horovodrun --check-build && \
    ldconfig

# Test to avoid race condition for different ranks executing entrypoint resulting in different LD_LIBRARY_PATHs
# if CUDA driver in container newer than on host (incompatible user-space CUDA libs being loaded/runtime NCCL test errors)
COPY nvidia_entrypoint_fix_tmp.sh /opt/nvidia/entrypoint.d/99-gpu-compat-library-path-fix.sh