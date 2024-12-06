function podman_prepare_build_context() {

    cp ../../utils/nvidia_entrypoint_fix.sh $1/nvidia_entrypoint_fix_tmp.sh

    function remove_entrypoint_fix_tmp() {
        rm nvidia_entrypoint_fix_tmp.sh
    }

    trap remove_entrypoint_fix_tmp EXIT

}
