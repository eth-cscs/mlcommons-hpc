#!/usr/bin/env bash


if [ "${ENABLE_NSYS:-0}" -eq 1 ]; then
    echo "Enabling profiling..."
    NSYS_ARGS="--stats=true --trace=cuda,cublas,nvtx --kill none -c cudaProfilerApi -f true"
    NSYS_OUTPUT=${PROFILE_OUTPUT:-"logs/R-${SLURM_JOB_NAME}-${SLURM_JOBID}-profile-r${SLURM_PROCID}"}
    export PROFILE_CMD="nsys profile $NSYS_ARGS -o $NSYS_OUTPUT"
fi

exec "$@"