#!/bin/bash

#SBATCH -J mlperf-cosmoflow
#SBATCH --nodes 4
#SBATCH --ntasks-per-node 4
#SBATCH --gpus-per-task 1
#SBATCH -t 4:00:00
#SBATCH -o logs/slurm-%x-%j.out

set -euo pipefail

source $SLURM_SUBMIT_DIR/../utils/all_ce.sh

mlc_utils_set_enroot_library_path
mlc_utils_set_enroot_extra_entrypoint


#export HOROVOD_TIMELINE=./timeline.json

export TF_CPP_MIN_LOG_LEVEL=0
export NCCL_DEBUG=INFO


mlc_utils_srun_disp_gpu_mem
trap mlc_utils_sbatch_disp_gpu_mem TERM EXIT KILL
mlc_utils_srun_dmesg_bg

set -x
srun -l -u --mpi=pmi2 --container-workdir=$(pwd) --environment="$(realpath env/ngc-cosmoflow-24.04.toml)" \
     ${SRUN_EXTRA_ARGS:-} ${ENROOT_EXTRA_ENTRYPOINT:-} bash -c " \
        hostname
        python train.py --mlperf -d --gpu 0 $@
"

set +x
mlc_utils_srun_disp_gpu_mem
mlc_utils_kill_dmesg_bg