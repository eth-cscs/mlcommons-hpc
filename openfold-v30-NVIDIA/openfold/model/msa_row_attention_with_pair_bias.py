# Copyright 2021 DeepMind Technologies Limited
# Copyright 2022 AlQuraishi Laboratory
# Copyright 2023 NVIDIA CORPORATION
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from typing import Optional

import torch
import torch.nn as nn

import openfold.dynamic_axial_parallelism as dap
from openfold.model.attention import SelfAttentionWithGate
from openfold.model.layer_norm import LayerNorm
from openfold.model.linear import Linear


class MSARowAttentionWithPairBias(nn.Module):
    """MSA Row Attention With Pair Bias module.

    Supplementary '1.6.1 MSA row-wise gated self-attention with pair bias': Algorithm 7.

    Args:
        c_m: MSA (or Extra MSA) representation dimension (channels).
        c_z: Pair representation dimension (channels).
        c_hidden: Per-head hidden dimension (channels).
        num_heads: Number of attention heads.
        inf: Safe infinity value.
        chunk_size: Optional chunk size for a batch-like dimension.

    """

    def __init__(
        self,
        c_m: int,
        c_z: int,
        c_hidden: int,
        num_heads: int,
        inf: float,
        chunk_size: Optional[int],
    ) -> None:
        super(MSARowAttentionWithPairBias, self).__init__()
        self.layer_norm_m = LayerNorm(c_m)
        self.layer_norm_z = LayerNorm(c_z)
        self.linear_z = Linear(c_z, num_heads, bias=False, init="normal")
        self.mha = SelfAttentionWithGate(
            c_qkv=c_m,
            c_hidden=c_hidden,
            num_heads=num_heads,
            inf=inf,
            chunk_size=chunk_size,
        )

    def forward(
        self,
        m: torch.Tensor,
        z: torch.Tensor,
        mask: torch.Tensor,
    ) -> torch.Tensor:
        """MSA Row Attention With Pair Bias forward pass.

        Args:
            m: [batch, N_seq, N_res, c_m] MSA (or Extra MSA) representation
            z: [batch, N_res, N_res, c_z] pair representation
            mask: [batch, N_seq, N_res] MSA (or Extra MSA) mask

        Returns:
            m_update: [batch, N_seq, N_res, c_m]
                MSA (or Extra MSA) representation update

        """
        mask = mask.unsqueeze(-2).unsqueeze(-3)
        # mask: [batch, N_seq, 1, 1, N_res]

        z = self.layer_norm_z(z)
        z = self.linear_z(z)
        if dap.is_enabled():
            z = dap.gather(z, dim=1, bwd="all_reduce_sum_split")
        # z: [batch, N_res, N_res, num_heads]

        z = z.movedim(-1, -3).unsqueeze(-4)
        # z: [batch, 1, num_heads, N_res, N_res]

        m = self.layer_norm_m(m)
        m = self.mha(
            input_qkv=m,
            mask=mask,
            bias=z,
        )
        # m: [batch, N_seq, N_res, c_m]

        return m
