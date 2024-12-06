#!/bin/bash

echo $(hostname) $(nvidia-smi|grep -o "|\s*[0-9]*MiB")