#!/bin/bash

# Chris' fix: https://cscs-lugano.slack.com/archives/C0802SGFMH8/p1732194381005259?thread_ts=1732123036.294079&cid=C0802SGFMH8

host_driver=`nvidia-smi --query-gpu=driver_version --format=csv | tail -n 1 | awk -F "." '{print $1}'`
container_driver=`echo $CUDA_DRIVER_VERSION | awk -F "." '{print $1}'`

if [ -n $host_driver ] ; then
    if [ -n $container_driver ] ; then
        echo "[nvidia_entrypoint_fix]: host_driver: $host_driver, container driver: $container_driver"
        if [ $container_driver -gt $host_driver ] ; then
            # Make sure the cuda forward compatible path is prepended in case   
            # there is a driver mismatch between the host and container
            echo "[nvidia_entrypoint_fix]: Container driver is newer than host driver - prepending compat path to LD_LIBRARY_PATH"
            export LD_LIBRARY_PATH=/usr/local/cuda/compat/lib.real:$LD_LIBRARY_PATH
            echo "[nvidia_entrypoint_fix]: RANK $SLURM_PROCID: new LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
        fi
    fi
fi
