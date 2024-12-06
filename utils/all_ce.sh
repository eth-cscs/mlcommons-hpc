if [ -z "${MLPERF_UTILS_ALL_CE_SH_INCLUDED:-}" ]; then
    MLPERF_UTILS_ALL_CE_SH_INCLUDED=1

    MLPERF_UTILS_DIR=$(dirname "${BASH_SOURCE[0]}")

    source "$MLPERF_UTILS_DIR/dmesg.sh"
    source "$MLPERF_UTILS_DIR/gpu_mem.sh"

    source "$MLPERF_UTILS_DIR/enroot.sh"

fi