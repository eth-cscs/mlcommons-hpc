#!/bin/bash

#SBATCH --job-name mlperf-ocp
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --gpus-per-task=1
#SBATCH --time 4:00:00
#SBATCH --output logs/slurm-%x-%j.out

set -euo pipefail

source $SLURM_SUBMIT_DIR/../utils/all_ce.sh

mlc_utils_set_enroot_library_path
mlc_utils_set_enroot_extra_entrypoint

# Default settings
: "${OCP_CONFIG:=configs/mlperf_hpc_alps.yml}"

seed=${2:-42}
id=ocp-n$SLURM_NNODES-`date +'%y%m%d-%H%M%S'`

# Distributed config
export MASTER_ADDR=$(hostname)
export MASTER_PORT=29500
export NCCL_DEBUG=INFO


mlc_utils_srun_disp_gpu_mem
trap mlc_utils_sbatch_disp_gpu_mem TERM EXIT KILL
mlc_utils_srun_dmesg_bg

set -x
srun -l -u --container-workdir=$(pwd) --environment="$(realpath env/ngc-open_catalyst-24.03.toml)" \
    ${SRUN_EXTRA_ARGS:-} ${ENROOT_EXTRA_ENTRYPOINT:-} bash -c "
    hostname
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

set +x
mlc_utils_srun_disp_gpu_mem
mlc_utils_kill_dmesg_bg