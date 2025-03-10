import sys

def allocate_gpu_memory_cupy(fraction):
    import cupy as cp

    total_memory_bytes = cp.cuda.Device().mem_info[1]

    bytes_to_allocate = total_memory_bytes * (fraction / 100)

    arr = cp.zeros(int(bytes_to_allocate // 4), dtype=cp.float32)

    print(f"Allocated {arr.nbytes / 1e9:.2f} GB of GPU memory in Cupy.")


def allocate_gpu_memory_pytorch(fraction):
    import torch

    device = torch.device('cuda')

    total_memory_bytes = torch.cuda.get_device_properties(device).total_memory

    bytes_to_allocate = total_memory_bytes * (fraction / 100)

    tensor = torch.ones(int(bytes_to_allocate // 4), dtype=torch.float32, device=device)

    print(f"Allocated {tensor.element_size() * tensor.nelement() / 1e9:.2f} GB of GPU memory in Pytorch.")


if len(sys.argv) > 2:
    fraction_to_allocate = float(sys.argv[2])
    assert 0 < fraction_to_allocate <= 100, "Fraction must be between 0 and 100"
else:
    fraction_to_allocate = 90

if sys.argv[1] == "cupy":
    allocate_gpu_memory_cupy(fraction_to_allocate)  # cf. https://docs.cupy.dev/en/stable/user_guide/memory.html
elif sys.argv[1] == "torch":
    allocate_gpu_memory_pytorch(fraction_to_allocate)
else:
    raise ValueError("Please specify 'cupy' or 'torch' as the first argument.")