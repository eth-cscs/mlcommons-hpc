#!/bin/bash

#SBATCH -J mlperf-cosmoflow
#SBATCH --nodes 4
#SBATCH --ntasks-per-node 4
#SBATCH -t 4:00:00
#SBATCH -o logs/%x-%j.out

#export HOROVOD_TIMELINE=./timeline.json

export TF_CPP_MIN_LOG_LEVEL=0
export NCCL_DEBUG=INFO

# Debugging (single rank, controlled by DEBUG_RANK, defaults to rank 0)
if [ "${ENABLE_DEBUGGING:-0}" -eq 1 ]; then
    ENROOT_ENTRYPOINT="env/enroot-entrypoint.sh"
else
    ENROOT_ENTRYPOINT=""
fi

set -x
srun -l -u --mpi=pmi2 --environment="$(realpath env/ngc-cosmoflow-24.04.toml)" ${ENROOT_ENTRYPOINT} bash -c " \
       CUDA_VISIBLE_DEVICES=\$SLURM_LOCALID \
       python train.py -d --rank-gpu $@
"