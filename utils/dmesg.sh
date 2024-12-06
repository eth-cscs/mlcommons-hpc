if [ -z "${MLPERF_UTILS_DMESG_SH_INCLUDED:-}" ]; then
    MLPERF_UTILS_DMESG_SH_INCLUDED=1
    
    # Record current GPU memory usage
    function mlc_utils_srun_dmesg_bg {

        if [ "${ENABLE_DMESG:-0}" -eq 1 ]; then
            local STARTTIME=$(squeue -h -j $SLURM_JOBID -o "%S")
            local ENDTIME=$(squeue -h -j $SLURM_JOBID -o "%e")

            echo "[dmesg.sh] Launching dmesg step in the background"
            # filter for dmesg output with 
            # grep -E '[0-9]{1,5}: \[[A-Za-z]{2} [A-Za-z]{3} [ ]?[0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}\]'
            srun -l -K -W $((`date -d "$ENDTIME" +%s` - `date +%s`)) \
                --ntasks-per-node=1 --ntasks="${SLURM_JOB_NUM_NODES}" \
                dmesg -Tw --since $STARTTIME &
            DMESG_PID=$!

            if [[ -z "${!SRUN_EXTRA_ARGS+x}" ]]; then
                SRUN_EXTRA_ARGS=""
            fi
            
            if [[ ! " ${SRUN_EXTRA_ARGS} " =~ " --overlap " ]]; then
                SRUN_EXTRA_ARGS+=" --overlap"
            fi
        fi

    }

    function mlc_utils_kill_dmesg_bg {

        if [ "${ENABLE_DMESG:-0}" -eq 1 ]; then
            kill $DMESG_PID
        fi

    }

fi