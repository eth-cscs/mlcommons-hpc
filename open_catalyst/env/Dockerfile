FROM nvcr.io/nvidia/pytorch:24.03-py3

RUN apt-get update \
  && apt-get install -yqq --no-install-recommends openssh-server \
  && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/sshd

# PyG
RUN FORCE_CUDA=1 TORCH_CUDA_ARCH_LIST="9.0" pip install --no-cache-dir \
    torch-scatter torch-sparse git+https://github.com/lukasgd/pytorch_geometric.git@1.7.2-fix
    # torch-geometric==1.7.2 fails in BesselBasisLayer due to
    # issue fixed in https://github.com/pyg-team/pytorch_geometric/pull/4424

# MLPerf logging
RUN pip install --no-cache-dir git+https://github.com/mlcommons/logging.git

# Other packages
RUN pip install --no-cache-dir ray submitit demjson3 wandb ase pymatgen lmdb==1.1.1
