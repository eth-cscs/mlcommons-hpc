if [ -z "${MLPERF_UTILS_GPUMEM_SH_INCLUDED:-}" ]; then
    MLPERF_UTILS_GPUMEM_SH_INCLUDED=1

    # Record current GPU memory usage
    function mlc_utils_srun_disp_gpu_mem {
        date
        srun --overlap -l $(dirname "${BASH_SOURCE[0]}")/disp_gpu_mem.sh
    }

    # Record post-job GPU memory usage
    # To submit automatically on failure, use: trap mlc_utils_sbatch_disp_gpu_mem TERM EXIT KILL
    function mlc_utils_sbatch_disp_gpu_mem() {

        sbatch -p $SLURM_JOB_PARTITION ${SLURM_JOB_RESERVATION:+--reservation ${SLURM_JOB_RESERVATION}} -w $SLURM_NODELIST -t2 \
            --ntasks=$SLURM_JOB_NUM_NODES --ntasks-per-node 1 \
            -o "$SLURM_SUBMIT_DIR/logs/slurm-$SLURM_JOB_NAME-$SLURM_JOBID.mem" \
            $(dirname "${BASH_SOURCE[0]}")/disp_gpu_mem.sh

    }

fi