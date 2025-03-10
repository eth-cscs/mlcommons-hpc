#!/usr/bin/python3

import os
import re
import json
import argparse
import numpy as np
from collections import OrderedDict


def extract_log_sections(file_path, start_marker, end_marker):

    sections = []
    current_section = []
    inside_section = False

    with open(file_path, 'r') as file:
        for line in file:
            # line = line.rstrip()
            if start_marker in line:
                inside_section = True
                current_section = []
                continue
            elif end_marker in line:
                inside_section = False
                sections.append(current_section)
                continue
            if inside_section:
                current_section.append(line)

    return sections


def parse_gpu_mem_entry(log_dict):

    gpu_mem_pattern = r'\s*(?P<rank>\d+):\s+(?P<hostname>nid\d+)\s+\|\s+(\d+)MiB\s+\|\s+(\d+)MiB\s+\|\s+(\d+)MiB\s+\|\s+(\d+)MiB'

    gpu_mem_list = []

    for line in log_dict["gpu_memory"].strip('\n').split('\n'):

        match = re.match(gpu_mem_pattern, line)

        if match:
            rank = int(match.group('rank'))
            hostname = match.group('hostname')
            values_mb = np.array([int(match.group(i)) for i in range(3, 7)])

            gpu_mem_list.append((rank, hostname, values_mb))

    gpu_mem_entry = OrderedDict()
    for rank, hostname, values_mb in sorted(gpu_mem_list):
        if hostname in gpu_mem_entry:
            gpu_mem_entry[hostname].append(np.array(values_mb))
        else:
            gpu_mem_entry[hostname] = [np.array(values_mb)]

    return gpu_mem_entry


def extract_gpu_mem_logs(file_path):

    gpu_mem_marker = "[gpu_mem.sh] GPU memory usage: {}"
    start_marker = gpu_mem_marker.format("start")
    end_marker = gpu_mem_marker.format("end")

    log_sections = extract_log_sections(file_path, start_marker, end_marker)

    # Contains the GPU memory usage data as a single string
    log_section_dicts = [json.loads(''.join(section), strict=False)
                         for section in log_sections]

    results = []

    for log_dict in log_section_dicts:
         
        gpu_mem_dict = parse_gpu_mem_entry(log_dict)

        results.append(dict(
            **{k:v for k,v in log_dict.items() if k != 'gpu_memory'},
            gpu_memory=OrderedDict((k, np.mean(v, axis=0)) for k, v in gpu_mem_dict.items())
        ))

    return results


def gpu_mem_dumps(gpu_mem):
    return '\n'.join(' | '.join([k] + [f"{int(v)} MiB" for v in values]) 
                            for k, values in gpu_mem.items())

def gpu_mem_diff(gpu_mem_start, gpu_mem_end, print_stdout=False,
                 desc_start='Start', desc_end='End'):
    end_vs_start_diff = OrderedDict()

    if gpu_mem_end:
        for k in gpu_mem_start['gpu_memory'].keys():
            end_vs_start_diff[k] = gpu_mem_end['gpu_memory'][k] - gpu_mem_start['gpu_memory'][k]

    if print_stdout:
        if gpu_mem_end:
            print(f"Difference in GPU memory {desc_end} vs {desc_start}:")
            print(gpu_mem_dumps(end_vs_start_diff))
        else:
            print(f"No GPU memory data for {desc_end}")

    return end_vs_start_diff
    

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Analyze GPU memory change pre/post SLURM job.')
    parser.add_argument('out', type=str, help='Path to the main output file.')
    # parser.add_argument('--separator', type=str, default='MLLOG',
    #                     help='Separator string between start and end collections.')
    args = parser.parse_args()

    out_file = args.out
    if not os.path.exists(out_file):
        raise FileNotFoundError(f"File {out_file} not found.")

    gpu_mem_logs = extract_gpu_mem_logs(args.out)
    
    assert len(gpu_mem_logs) > 0, f"No GPU memory logs found in {out_file}."
    gpu_mem_start = gpu_mem_logs[0]

    print(f"GPU memory logs in {out_file}:\n")
    for i, gpu_mem_log in enumerate(gpu_mem_logs):
        print(f"GPU memory out/{i} [{gpu_mem_log['time']}]:")
        print(gpu_mem_dumps(gpu_mem_log['gpu_memory']))
        print()
    
    mem_file = args.out[:-4] + '.mem'
    if os.path.exists(mem_file):
        gpu_mem_post_job_logs = extract_gpu_mem_logs(args.out[:-4] + '.mem')
    
        print(f"GPU memory logs in {mem_file}:\n")
        for i, gpu_mem_log in enumerate(gpu_mem_post_job_logs):
            print(f"Post-job GPU memory mem/{i} [{gpu_mem_log['time']}]:")
            print(gpu_mem_dumps(gpu_mem_log['gpu_memory']))
            print()
    else:
        gpu_mem_post_job_logs = []

    # Compare GPU memory logs
    # By default all logs are compared to the first one. Could introduce CLI arguments to change this.

    for i, gpu_mem_log in enumerate(gpu_mem_logs[1:]):
        end_vs_start_diff = gpu_mem_diff(gpu_mem_start, gpu_mem_log,
                                         print_stdout=True, desc_start=f"out/0", desc_end=f"out/{i+1}")

    for i, gpu_mem_log in enumerate(gpu_mem_post_job_logs):
        post_job_vs_start_diff = gpu_mem_diff(gpu_mem_start, gpu_mem_log,
                                              print_stdout=True, desc_start=f"out/0", desc_end=f"post-job/{i}")

