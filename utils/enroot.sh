if [ -z "${MLPERF_UTILS_ENROOT_SH_INCLUDED:-}" ]; then
    MLPERF_UTILS_ENROOT_SH_INCLUDED=1

    function mlc_utils_set_enroot_library_path() {

        if [ "${SLURM_JOB_RESERVATION:-none}" = "oldimg" ]; then
            export ENROOT_LIBRARY_PATH=/capstor/scratch/cscs/fmohamed/enrootlibxpmem
        else
            export ENROOT_LIBRARY_PATH=/capstor/scratch/cscs/fmohamed/enrootlibn
        fi

    }

    function mlc_utils_set_enroot_extra_entrypoint() {

        # Debugging (single rank, controlled by DEBUG_RANK, defaults to rank 0)
        if [ "${ENABLE_DEBUGGING:-0}" -eq 1 ]; then
            ENROOT_EXTRA_ENTRYPOINT="$(dirname "${BASH_SOURCE[0]}")/enroot-entrypoint.sh"
        else
            ENROOT_EXTRA_ENTRYPOINT=""
        fi
        
    }


fi