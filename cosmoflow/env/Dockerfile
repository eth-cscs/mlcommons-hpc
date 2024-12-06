FROM nvcr.io/nvidia/tensorflow:24.04-tf2-py3

RUN apt-get update \
  && apt-get install -yqq --no-install-recommends \
    build-essential \
    automake \
    autoconf \
    libtool \
    cmake \
    git \
    curl \
    vim \
    wget \
    strace \
    ca-certificates \
    pkg-config \
    openssh-server \
  && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/sshd

RUN python -m pip install --no-cache-dir -U pip

RUN pip install --no-cache-dir pandas wandb

# Install MLPerf-logging
RUN pip install --no-cache-dir "git+https://github.com/mlcommons/logging.git"

RUN pip uninstall -y horovod

RUN python -m pip install --no-cache-dir -U pip

ARG LIBFABRIC_VERSION=1.15.1
ARG MPICH_VERSION=4.2.1

# Install libfabric
RUN wget -q https://github.com/ofiwg/libfabric/archive/v${LIBFABRIC_VERSION}.tar.gz \
    && tar xf v${LIBFABRIC_VERSION}.tar.gz \
    && cd libfabric-${LIBFABRIC_VERSION} \
    && ./autogen.sh \
    && ./configure --prefix=/usr --with-cuda=/usr/local/cuda \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && cd .. \
    && rm -rf v${LIBFABRIC_VERSION}.tar.gz libfabric-${LIBFABRIC_VERSION}

# Install MPICH
RUN wget -q https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz \
    && tar xf mpich-${MPICH_VERSION}.tar.gz \
    && cd mpich-${MPICH_VERSION} \
    && ./autogen.sh \
    && ./configure --prefix=/usr/local/mpich --enable-fast=O3,ndebug \
       --disable-fortran --disable-cxx \
       --with-device=ch4:ofi --with-libfabric=/usr \
       --with-cuda=/usr/local/cuda \
       CFLAGS="-L/usr/local/cuda/targets/sbsa-linux/lib/stubs/ -lcuda" \
       CXXFLAGS="-L/usr/local/cuda/targets/sbsa-linux/lib/stubs/ -lcuda" \
    && make -j$(nproc) \
    && make install \
    && echo "/usr/local/mpich" > /etc/ld.so.conf.d/mpich.conf \
    && ldconfig \
    && cd .. \
    && rm -rf mpich-${MPICH_VERSION}.tar.gz mpich-${MPICH_VERSION}

# Set MPICH compiler wrappers to have precedence over the OpenMPI ones coming
# form the base NGC image
ENV PATH=/usr/local/mpich/bin:${PATH}

ARG HOROVOD_VERSION=0.28.1
WORKDIR /horovod
RUN ldconfig /usr/local/cuda/targets/sbsa-linux/lib/stubs && \
    MPI_HOME=/usr/local/mpich HOROVOD_GPU_OPERATIONS=NCCL HOROVOD_WITH_TENSORFLOW=1 HOROVOD_WITH_MPI=1 \
    pip install --no-cache-dir -v git+https://github.com/horovod/horovod.git@v${HOROVOD_VERSION} && \
    horovodrun --check-build && \
    ldconfig

# Test to avoid race condition for different ranks executing entrypoint resulting in different LD_LIBRARY_PATHs
# if CUDA driver in container newer than on host (incompatible user-space CUDA libs being loaded/runtime NCCL test errors)
COPY nvidia_entrypoint_fix_tmp.sh /opt/nvidia/entrypoint.d/99-gpu-compat-library-path-fix.sh