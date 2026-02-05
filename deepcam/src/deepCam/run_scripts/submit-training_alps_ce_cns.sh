#!/bin/bash

CE_ENV_TOML=env/cray-network-stack-ngc-deepcam-25.12.toml \
  SRUN_EXTRA_ARGS="--mpi=pmix" \
  data_dir=/capstor/store/cscs/cscs/csstaff/lukasd/deepcam/All-Hist/ \
  sbatch --nodes 8 --time 2:00:00 src/deepCam/run_scripts/run_training_alps_ce.sh --n-epochs 2