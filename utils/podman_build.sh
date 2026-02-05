if [ -z "${MLPERF_UTILS_PODMAN_BUILD_SH_INCLUDED:-}" ]; then
    MLPERF_UTILS_PODMAN_BUILD_SH_INCLUDED=1

    function podman_prepare_build_context() {

        cp ../../utils/nvidia_entrypoint_fix.sh $1/nvidia_entrypoint_fix_tmp.sh

        function remove_entrypoint_fix_tmp() {
            rm nvidia_entrypoint_fix_tmp.sh
        }

        trap remove_entrypoint_fix_tmp EXIT

    }

    function podman_build_enroot_import() {
        local IMAGE=$1
        local SQSH_FILE=${ENROOT_IMAGES:-${CAPSCRATCH:-$SCRATCH}/images}/${IMAGE//:/+}.sqsh

        if [ -f $SQSH_FILE ]; then
            echo "Error: Squash image already exists: $SQSH_FILE"
            return 1
        fi

        set -x
        podman build -t $USER/$IMAGE "${@:2}" || { STATUS=$?; set +x; echo "Error: podman build failed (exit code: $STATUS)"; return $STATUS; }
        enroot import -x mount -o ${SQSH_FILE} podman://$USER/$IMAGE || { STATUS=$?; set +x; if [ ! -f "${SQSH_FILE}" ]; then echo "Error: enroot import failed (exit code: $STATUS)"; return $STATUS; else return 0; fi }
        set +x
    }

    function podman_utils_container_registry() {
        local image=$1
        IFS='/' read -r -a base_image_array <<< ${image%:*}

        local length=${#base_image_array[@]}
        
        if [ "${length}" -eq 2 ]; then
            echo "${base_image_array[0]}"
        else
            local container_registry="${base_image_array[$((length - 2))]}"
            
            if [ "${container_registry}" = "nvidia" ]; then
                echo "ngc"
            elif [ "${container_registry}" = "rocm" ]; then
                echo "rocm"
            else
                echo "Error: Unsupported container registry" >&2
                exit 1
            fi
        fi
    }

    function podman_utils_tag_short() {
        local image=$1
        local registry=$(podman_utils_container_registry $image)
        if [ "${registry}" = "ngc" ]; then
            IFS='-_' read -r -a base_tag_array <<< ${image#*:}
            echo "${base_tag_array[0]}"
        elif [ "${registry}" = "rocm" ]; then
            IFS='-_' read -r -a base_tag_array <<< ${image#*:}

            local length=${#base_tag_array[@]}
            local suffix=${base_tag_array[$((length - 1))]}

            if [[ "${suffix}" =~ ^(dev|runtime|preview)$ ]]; then
                if [[ "${base_tag_array[$((length - 2))]}" != tf* ]]; then
                    base_tag_array[$((length - 2))]="pt${base_tag_array[$((length - 2))]}"
                fi
                echo "${base_tag_array[0]#rocm}-${base_tag_array[$((length - 2))]}-${suffix}"
            elif [[ ${length} -gt 1 ]]; then
                if [[ "${suffix}" =~ "_pytorch_" ]]; then
                    suffix="pt${suffix}"
                fi

                echo "${base_tag_array[0]#rocm}-${suffix}"
            else
                echo ${suffix}
            fi
        else
            echo "Error: Unsupported container registry" >&2
            exit 1
        fi
    }

    if [ "$0" = "$BASH_SOURCE" ]; then
        podman_build_enroot_import "$@"
    fi

fi