#!/bin/bash

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

#SBATCH --job-name=mlperf-deepcam
#SBATCH --time=03:30:00
#SBATCH --nodes=128
#SBATCH --ntasks-per-node=4
#SBATCH --output logs/slurm-%x-%j.out

# Equivalent salloc command to run this script on the login node (e.g. required by SSH annotation):
# salloc --job-name=mlperf-deepcam --time=03:30:00 --nodes=128 --ntasks-per-node=1 ./run_training_alps_ce.sh
# (--output is ignored by salloc as it streams to the terminal)


set -euo pipefail  # comment for memory debugging

export SLURM_CPU_BIND="verbose"

if nvidia-smi &> /dev/null; then
    export SLURM_GPUS_PER_TASK=1
    export SLURM_CPUS_PER_TASK=72
    : "${CE_ENV_TOML="env/ngc-deepcam-24.03.toml"}"
elif rocm-smi &> /dev/null; then
    export SLURM_CPUS_PER_TASK=24
    # : "${CE_ENV_TOML="env/rocm-deepcam-6.3.3-pt2.4.0.toml"}"
    : "${CE_ENV_TOML="env/rocm-deepcam+6.4.4-2.7.1.toml"}"
    # : "${CE_ENV_TOML="env/rocm-deepcam+7.1.1-2.9.1.toml"}"
    # : "${CE_ENV_TOML="env/rocm-deepcam+v25.9-gfx942.toml"}"
else
    echo "Error: No CPU-only environment available."
fi

. $SLURM_SUBMIT_DIR/../utils/all_ce.sh

mlc_utils_set_enroot_entrypoint

mkdir -p logs

while [[ $# -gt 0 ]]; do
    case $1 in
        --n-epochs)
            max_epochs=$2
            shift 2
            ;;
        --n-train)
            n_train=$2
            shift 2
            ;;
        --n-valid)
            n_valid=$2
            shift 2
            ;;
        --wandb)
            enable_wandb=1
            shift 1
            ;;
        *)
            break
            ;;
    esac
done

# parameters (can be overriden through environment)
: ${max_epochs:=28}

if [ $# -ge 1 ] && [ "$1" == "mini" ]; then
    data_dir="/iopsstor/scratch/cscs/lukasd/ds/mlperf/data/deepcam/deepcam-data-mini/mini-1"
else
    data_dir=${data_dir:-"/iopsstor/scratch/cscs/lukasd/ds/mlperf/data/deepcam/All-Hist/"}
fi
output_dir=${output_dir:-"./runs/"}
local_batch_size=${local_batch_size:-12}
global_batch_size=$(( $local_batch_size * $SLURM_NTASKS ))
valid_batch_size=${valid_batch_size:-12}
seed=${seed:-$(date +%s)}
run_tag=${run_tag:-"b$(printf '%04d' $global_batch_size)_j$SLURM_JOBID"}

# set learning rate schedule according to RCPs
case $global_batch_size in 
    128)
        LR=0.0010
        lr_warmup_steps=0
        lr_schedule_milestones="8192 16384"
        ;;
    256)
        LR=0.0020
        lr_warmup_steps=0
        lr_schedule_milestones="4096 8192"
        ;;
    512)
        LR=0.0040
        lr_warmup_steps=100
        lr_schedule_milestones="2048 4096"
        ;;
    1024)
        LR=0.0040
        lr_warmup_steps=200
        lr_schedule_milestones="1100 4096"    
        ;;
    2048)
        LR=0.0055
        lr_warmup_steps=400
        lr_schedule_milestones="800"
        ;;
    *)
        echo "No RCP for this global batch size ${global_batch_size} - using default instead."
        LR=$( bc  <<< "0.0000078125 * $global_batch_size" )  # linear (0.001 at bs128)
        LR_STEP0=$( bc <<< "1048576 / $global_batch_size" )  # RCP ([ 8192, 16384 ] at bs128) == Epochs [ 8.35, 16.7 ]
        LR_STEP1=$( bc <<< "2097152 / $global_batch_size" )
        lr_warmup_steps=400
        lr_schedule_milestones="$LR_STEP0 $LR_STEP1"
        ;;
esac

echo "milestones='$lr_schedule_milestones' bz=$global_batch_size lr=$LR warmup=$lr_warmup_steps"


mlc_utils_srun_disp_gpu_mem
trap mlc_utils_sbatch_disp_gpu_mem TERM EXIT KILL
mlc_utils_srun_dmesg_bg

set -x
# for i in $(seq 1 100); do  # memory debugging

# observe open files on /tmp with: watch -n 1 "ls -al /proc/*/fd/* 2>/dev/null | grep '/tmp' | awk '{print \$9, \$10, \$11}'"


srun -ul --container-workdir=$(pwd) --environment="$(realpath ${CE_ENV_TOML})" \
    ${SRUN_EXTRA_ARGS:-} ${ENROOT_ENTRYPOINT:-} bash -c " \
       hostname
       export SLURM_NTASKS_PER_NODE=\${SLURM_TASKS_PER_NODE%%(*}

       MIOPEN_VERSION=\$(awk '/^#define MIOPEN_VERSION_(MAJOR|MINOR|PATCH) / {print \$3}' /opt/rocm/include/miopen/version.h | paste -sd.)
       ROCM_VERSION=\$(cat /opt/rocm/.info/version)
       export MIOPEN_CUSTOM_CACHE_DIR=/tmp/.cache/miopen\$MIOPEN_VERSION-rocm\$ROCM_VERSION-\$SLURM_JOB_ID-\$SLURM_PROCID
       export MIOPEN_USER_DB_PATH=\$MIOPEN_CUSTOM_CACHE_DIR

       set -x

       export PYTORCH_TUNABLEOP_VEROBSE=1

       export MIOPEN_ENABLE_LOGGING=1
       export MIOPEN_ENABLE_LOGGING_CMD=1
       export MIOPEN_ENABLE_LOGGING_MPMT=1
       export MIOPEN_LOG_LEVEL=7
       export MIOPEN_ENABLE_LOGGING_ELAPSED_TIME=1
       export MIOPEN_CHECK_NUMERICS=1
       export MIOPEN_COMPILE_PARALLEL_LEVEL=\$((\$(nproc)/4))

       echo \${MIOPEN_DEBUG_GCN_ASM_KERNELS:-}
       echo \${MIOPEN_INIT_PREFER_GEMM:-}
       echo \${MIOPEN_FIND_MODE:-}
       echo \${MIOPEN_DEBUG_CONV_IMPLICIT_GEMM:-}

    #    # Further options
    ##    export MIOPEN_DEBUG_FORBID_SOLVERS=ConvHipImplicitGemmGroupFwdXdlops
    #    export MIOPEN_DEBUG_CONV_FFT=0
    #    export MIOPEN_DEBUG_CONV_DIRECT=0
    #    export MIOPEN_DEBUG_CONV_GEMM=0
    #    export MIOPEN_DEBUG_CONV_WINOGRAD=0
    #    export MIOPEN_DEBUG_CONV_IMPLICIT_GEMM=0

       mkdir -p \$MIOPEN_CUSTOM_CACHE_DIR

       cd src/deepCam
       set -x
       #strace \
       python ./train.py \
       --wireup_method \"nccl-slurm\" \
       --run_tag ${run_tag} \
       --data_dir_prefix ${data_dir} \
       --output_dir ${output_dir} \
       --model_prefix \"segmentation\" \
       --optimizer \"LAMB\" \
       --start_lr $LR \
       --lr_schedule type=\"multistep\",milestones=\"${lr_schedule_milestones}\",decay_rate=\"0.1\" \
       --lr_warmup_steps ${lr_warmup_steps} \
       --lr_warmup_factor 1. \
       --weight_decay 1e-2 \
       --logging_frequency 10 \
       --save_frequency 0 \
       --max_epochs ${max_epochs} \
       --max_inter_threads 12 \
       --seed ${seed} \
       --batchnorm_group_size 1 \
       --local_batch_size ${local_batch_size} \
       ${n_train+--n_train=${n_train}} \
       ${n_valid+--n_valid=${n_valid}} \
       ${enable_wandb+--wandb}
" #&  # memory debugging

#     SLURM_TRAINING_STEP_PID=$!
#     sleep 120
#     kill $SLURM_TRAINING_STEP_PID

#     echo "Checking post-job GPU memory $i..."
#     mlc_utils_srun_disp_gpu_mem
# done # memory debugging

set +x
mlc_utils_srun_disp_gpu_mem
mlc_utils_kill_dmesg_bg