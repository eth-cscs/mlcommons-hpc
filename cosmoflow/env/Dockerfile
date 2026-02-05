ARG BASE_IMAGE 
FROM ${BASE_IMAGE}

RUN apt-get update \
  && apt-get install -yqq --no-install-recommends strace valgrind htop nvtop atop ioping fio tree \
  && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/sshd

RUN python -m pip install --no-cache-dir -U pip

RUN pip uninstall -y horovod

# ENV MPICH_VER=4.2.1

# RUN wget -q http://www.mpich.org/static/downloads/${MPICH_VER}/mpich-${MPICH_VER}.tar.gz \
#     && tar xf mpich-${MPICH_VER}.tar.gz \
#     && cd mpich-${MPICH_VER} \
#     && ./configure --disable-fortran --with-device=ch3:sock -prefix=/usr \
#     && make -j 3 \ 
#     && make install \
#     && cd .. \
#     && rm -rf mpich-${MPICH_VER} \
#     && rm mpich-${MPICH_VER}.tar.gz

RUN CXX=mpic++ CC=mpicc pip install mpi4py

    # MAKEFLAGS=-j32 MPI_HOME=/usr HOROVOD_GPU_OPERATIONS=NCCL HOROVOD_WITHOUT_MXNET=1 HOROVOD_WITH_TENSORFLOW=1 HOROVOD_WITHOUT_PYTORCH=1 HOROVOD_WITH_MPI=1 \
RUN ldconfig /usr/local/cuda/targets/sbsa-linux/lib/stubs && \
    MAKEFLAGS=-j32 HOROVOD_GPU_OPERATIONS=NCCL HOROVOD_WITHOUT_MXNET=1 HOROVOD_WITH_TENSORFLOW=1 HOROVOD_WITHOUT_PYTORCH=1 HOROVOD_WITH_MPI=1 \
    pip install --no-cache-dir -v git+https://github.com/horovod/horovod.git && \
    horovodrun --check-build && \
    ldconfig

RUN pip install --no-cache-dir pandas wandb

# Install MLPerf-logging
RUN pip install --no-cache-dir --no-deps "git+https://github.com/mlcommons/logging.git"
    