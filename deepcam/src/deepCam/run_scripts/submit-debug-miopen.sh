#!/bin/bash

# max_epochs=5 ENABLE_DEBUGGING=1 sbatch -N 1 -p mi300 src/deepCam/run_scripts/run_training_alps_ce.sh mini

# Define the environment variables and their values
vars=(
    "MIOPEN_DEBUG_GCN_ASM_KERNELS=0"
    "MIOPEN_INIT_PREFER_GEMM=1"
    "MIOPEN_FIND_MODE=2"
    "MIOPEN_DEBUG_CONV_IMPLICIT_GEMM=0"
)

# Get the number of variables
num_vars=${#vars[@]}

# Calculate the total number of subsets (2^num_vars)
num_subsets=$((1 << num_vars))

# Loop through all subsets
for (( i=0; i<num_subsets; i++ )); do
    env_vars=""
    for (( j=0; j<num_vars; j++ )); do
        # Check if the j-th bit is set in i
        if (( (i >> j) & 1 )); then
            env_vars="$env_vars ${vars[j]}"
        fi
    done
    
    # Execute the command with the current subset of environment variables
    env $env_vars max_epochs=5 ENABLE_DEBUGGING=1 sbatch -N 1 -p mi300 src/deepCam/run_scripts/run_training_alps_ce-rocm-dev.sh mini
done




# logs/slurm-mlperf-deepcam-187463.out: MIOPEN_DEBUG_GCN_ASM_KERNELS=0 MIOPEN_FIND_MODE=2
# logs/slurm-mlperf-deepcam-187465.out: MIOPEN_DEBUG_GCN_ASM_KERNELS=0 MIOPEN_INIT_PREFER_GEMM=1 MIOPEN_FIND_MODE=2
# logs/slurm-mlperf-deepcam-187467.out: MIOPEN_DEBUG_GCN_ASM_KERNELS=0 MIOPEN_DEBUG_CONV_IMPLICIT_GEMM=0
# logs/slurm-mlperf-deepcam-187469.out: MIOPEN_DEBUG_GCN_ASM_KERNELS=0 MIOPEN_INIT_PREFER_GEMM=1 MIOPEN_DEBUG_CONV_IMPLICIT_GEMM=0
# logs/slurm-mlperf-deepcam-187471.out: MIOPEN_DEBUG_GCN_ASM_KERNELS=0 MIOPEN_FIND_MODE=2 MIOPEN_DEBUG_CONV_IMPLICIT_GEMM=0
# logs/slurm-mlperf-deepcam-187473.out: MIOPEN_DEBUG_GCN_ASM_KERNELS=0 MIOPEN_INIT_PREFER_GEMM=1 MIOPEN_FIND_MODE=2 MIOPEN_DEBUG_CONV_IMPLICIT_GEMM=0