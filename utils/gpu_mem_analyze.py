#!/usr/bin/python3

import os
import re
import json
import argparse
import numpy as np
from collections import OrderedDict


def parse_log_file(file_path, separator='MLLOG'):

    gpu_mem_pattern = r'\s*(?P<rank>\d+):\s+(?P<hostname>nid\d+)\s+\|\s+(\d+)MiB\s+\|\s+(\d+)MiB\s+\|\s+(\d+)MiB\s+\|\s+(\d+)MiB'

    gpu_mem_start_list = []
    gpu_mem_end_list = []

    current_list = gpu_mem_start_list

    with open(file_path, 'r') as file:
        for line in file:
            if separator in line:
                current_list = gpu_mem_end_list
                continue

            match = re.match(gpu_mem_pattern, line)

            if match:
                rank = int(match.group('rank'))
                hostname = match.group('hostname')
                values_mb = np.array([int(match.group(i)) for i in range(3, 7)])

                current_list.append((rank, hostname, values_mb))

    gpu_mem_start = OrderedDict()
    gpu_mem_end = OrderedDict()
    for current_list, current_dict in zip([gpu_mem_start_list, gpu_mem_end_list],
                                          [gpu_mem_start, gpu_mem_end]):
        for rank, hostname, values_mb in sorted(current_list):
            if hostname in current_dict:
                current_dict[hostname].append(np.array(values_mb))
            else:
                current_dict[hostname] = [np.array(values_mb)]

    return OrderedDict((k, np.mean(v, axis=0)) for k, v in gpu_mem_start.items()), \
        OrderedDict((k, np.mean(v, axis=0)) for k, v in gpu_mem_end.items())


def gpu_mem_dumps(gpu_mem):
    return '\n'.join(' | '.join([k] + [f"{int(v)} MiB" for v in values]) 
                            for k, values in gpu_mem.items())

def gpu_mem_diff(gpu_mem_start, gpu_mem_end, print_stdout=False,
                 desc_start='Start', desc_end='End'):
    end_vs_start_diff = OrderedDict()

    if gpu_mem_end:
        for k in gpu_mem_start.keys():
            end_vs_start_diff[k] = gpu_mem_end[k] - gpu_mem_start[k]

    if print_stdout:
        if gpu_mem_end:
            print(f"Difference in GPU memory ({desc_end} vs {desc_start}):")
            print(gpu_mem_dumps(end_vs_start_diff))
        else:
            print(f"No GPU memory data for {desc_end}")

    return end_vs_start_diff
    

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Analyze GPU memory change pre/post SLURM job.')
    parser.add_argument('out', type=str, help='Path to the main output file.')
    parser.add_argument('--separator', type=str, default='MLLOG',
                        help='Separator string between start and end collections.')
    args = parser.parse_args()

    out_file = args.out
    if not os.path.exists(out_file):
        raise FileNotFoundError(f"File {out_file} not found.")

    gpu_mem_start, gpu_mem_end = parse_log_file(args.out, separator=args.separator)

    print("Start GPU memory:")
    print(gpu_mem_dumps(gpu_mem_start))
    print()
    print("End GPU memory:")
    print(gpu_mem_dumps(gpu_mem_end))
    print()
    
    mem_file = args.out[:-4] + '.mem'
    if os.path.exists(mem_file):
        gpu_mem_post_job, _ = parse_log_file(args.out[:-4] + '.mem', separator=args.separator)

        print("Post-job GPU memory:")
        print(gpu_mem_dumps(gpu_mem_post_job))
        print()
    else:
        gpu_mem_post_job = OrderedDict()

    end_vs_start_diff = gpu_mem_diff(gpu_mem_start, gpu_mem_end, print_stdout=True)

    post_job_vs_start_diff = gpu_mem_diff(gpu_mem_start, gpu_mem_post_job, print_stdout=True,
                                          desc_end='Post-job')

