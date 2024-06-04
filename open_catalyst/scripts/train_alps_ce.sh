#!/bin/bash

#SBATCH --job-name mlperf-ocp
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --time 4:00:00
#SBATCH --output logs/slurm-%x-%j.out

# Default settings
: "${OCP_CONFIG:=configs/mlperf_hpc_alps.yml}"

seed=${2:-42}
id=ocp-n$nodes-`date +'%y%m%d-%H%M%S'`

# Distributed config
export MASTER_ADDR=$(hostname)
export MASTER_PORT=29500
export NCCL_DEBUG=INFO

# Debugging (single rank, controlled by DEBUG_RANK, defaults to rank 0)
if [ "${ENABLE_DEBUGGING:-0}" -eq 1 ]; then
    ENROOT_ENTRYPOINT="env/enroot-entrypoint.sh"
else
    ENROOT_ENTRYPOINT=""
fi

set -x
srun -l -u --environment="$(realpath env/ngc-open_catalyst-24.03.toml)" ${ENROOT_ENTRYPOINT} bash -c "
    hostname
    CUDA_VISIBLE_DEVICES=\$SLURM_LOCALID \
    scripts/run_training.sh \
    --config-yml $OCP_CONFIG \
    --seed $seed \
    --identifier $id \
    --num-nodes $SLURM_NNODES \
    --slurm-timeout 8 \
    --run-dir=runs/$id \
    --logdir=logs \
    # --amp
"
