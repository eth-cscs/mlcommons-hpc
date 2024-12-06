# The MIT License (MIT)
#
# Copyright (c) 2020 NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

FROM nvcr.io/nvidia/pytorch:23.04-py3

RUN apt-get update \
  && apt-get install -yqq --no-install-recommends openssh-server \
  && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/sshd

# some requirements
RUN pip install h5py

#install mpi4py
RUN pip install mpi4py==3.1.6

#install warmup-scheduler
RUN pip install "git+https://github.com/ildoonet/pytorch-gradual-warmup-lr.git@6b5e8953a80aef5b324104dc0c2e9b8c34d622bd"

#install mlperf logging
RUN pip install "git+https://github.com/mlperf/logging.git@501bbde47f005d67c6357da6e5c1931eab339f8e"

# #copy additional stuff
# COPY src/deepCam /opt/deepCam
# COPY src/utils /opt/utils

# #create additional folders for mapping data in
# RUN mkdir -p /data

# Test to avoid race condition for different ranks executing entrypoint resulting in different LD_LIBRARY_PATHs
# if CUDA driver in container newer than on host (incompatible user-space CUDA libs being loaded/runtime NCCL test errors)
COPY nvidia_entrypoint_fix_tmp.sh /opt/nvidia/entrypoint.d/99-gpu-compat-library-path-fix.sh