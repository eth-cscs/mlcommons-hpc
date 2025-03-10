#!/bin/bash

#SBATCH --job-name mlperf-cosmoflow
#SBATCH --time 4:00:00
#SBATCH --nodes 4
#SBATCH --ntasks-per-node 4
#SBATCH --output logs/slurm-%x-%j.out

set -euo pipefail

export SLURM_CPU_BIND="verbose"

if command -v nvidia-smi &> /dev/null; then
    export SLURM_GPUS_PER_TASK=1
    export SLURM_CPUS_PER_TASK=72
    gpu_id=0
    CE_ENV_TOML="env/ngc-cosmoflow-24.04.toml"
elif command -v rocm-smi &> /dev/null; then
    export SLURM_CPUS_PER_TASK=24
    gpu_id="\$SLURM_LOCALID"
    CE_ENV_TOML="env/rocm-cosmoflow-6.3.3-tf2.15.toml"
else
    echo "Error: No CPU-only environment available."
fi

. $SLURM_SUBMIT_DIR/../utils/all_ce.sh


mlc_utils_set_enroot_entrypoint

#export HOROVOD_TIMELINE=./timeline.json

export TF_CPP_MIN_LOG_LEVEL=0
export NCCL_DEBUG=INFO


mlc_utils_srun_disp_gpu_mem
trap mlc_utils_sbatch_disp_gpu_mem TERM EXIT KILL
mlc_utils_srun_dmesg_bg

set -x
srun -l -u --mpi=pmi2 --container-workdir=$(pwd) --environment="$(realpath ${CE_ENV_TOML})" \
     ${SRUN_EXTRA_ARGS:-} ${ENROOT_ENTRYPOINT:-} bash -c " \
        hostname
        export SLURM_NTASKS_PER_NODE=\${SLURM_TASKS_PER_NODE%%(*}
        set -x
        python train.py --mlperf --distributed --gpu ${gpu_id} \"\$@\"
" _ "$@"  # --verbose --wandb for extended logging

set +x
mlc_utils_srun_disp_gpu_mem
mlc_utils_kill_dmesg_bg