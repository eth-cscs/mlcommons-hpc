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

from functools import partial
from typing import Optional, Tuple

import torch
import torch.nn as nn
from torch.utils.checkpoint import checkpoint as gradient_checkpointing_fn

import openfold.dynamic_axial_parallelism as dap
from openfold.model.evoformer_block import EvoformerBlock
from openfold.model.linear import Linear


class EvoformerStack(nn.Module):
    """Evoformer Stack module.

    Supplementary '1.6 Evoformer blocks': Algorithm 6.

    Args:
        c_m: MSA representation dimension (channels).
        c_z: Pair representation dimension (channels).
        c_hidden_msa_att: Hidden dimension in MSA attention.
        c_hidden_opm: Hidden dimension in outer product mean.
        c_hidden_tri_mul: Hidden dimension in multiplicative updates.
        c_hidden_tri_att: Hidden dimension in triangular attention.
        c_s: Single representation dimension (channels).
        num_heads_msa: Number of heads used in MSA attention.
        num_heads_tri: Number of heads used in triangular attention.
        num_blocks: Number of blocks in the stack.
        transition_n: Channel multiplier in transitions.
        msa_dropout: Dropout rate for MSA activations.
        pair_dropout: Dropout rate for pair activations.
        inf: Safe infinity value.
        eps_opm: Epsilon to prevent division by zero in outer product mean.
        chunk_size_msa_att: Optional chunk size for a batch-like dimension
            in MSA attention.
        chunk_size_opm: Optional chunk size for a batch-like dimension
            in outer product mean.
        chunk_size_tri_att: Optional chunk size for a batch-like dimension
            in triangular attention.

    """

    def __init__(
        self,
        c_m: int,
        c_z: int,
        c_hidden_msa_att: int,
        c_hidden_opm: int,
        c_hidden_tri_mul: int,
        c_hidden_tri_att: int,
        c_s: int,
        num_heads_msa: int,
        num_heads_tri: int,
        num_blocks: int,
        transition_n: int,
        msa_dropout: float,
        pair_dropout: float,
        inf: float,
        eps_opm: float,
        chunk_size_msa_att: Optional[int],
        chunk_size_opm: Optional[int],
        chunk_size_tri_att: Optional[int],
    ) -> None:
        super(EvoformerStack, self).__init__()
        self.blocks = nn.ModuleList(
            [
                EvoformerBlock(
                    c_m=c_m,
                    c_z=c_z,
                    c_hidden_msa_att=c_hidden_msa_att,
                    c_hidden_opm=c_hidden_opm,
                    c_hidden_tri_mul=c_hidden_tri_mul,
                    c_hidden_tri_att=c_hidden_tri_att,
                    num_heads_msa=num_heads_msa,
                    num_heads_tri=num_heads_tri,
                    transition_n=transition_n,
                    msa_dropout=msa_dropout,
                    pair_dropout=pair_dropout,
                    inf=inf,
                    eps_opm=eps_opm,
                    chunk_size_msa_att=chunk_size_msa_att,
                    chunk_size_opm=chunk_size_opm,
                    chunk_size_tri_att=chunk_size_tri_att,
                )
                for _ in range(num_blocks)
            ]
        )
        self.linear = Linear(c_m, c_s, bias=True, init="default")

    def forward(
        self,
        m: torch.Tensor,
        z: torch.Tensor,
        msa_mask: torch.Tensor,
        pair_mask: torch.Tensor,
        gradient_checkpointing: bool,
    ) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        """Evoformer Stack forward pass.

        Args:
            m: [batch, N_seq, N_res, c_m] MSA representation
            z: [batch, N_res, N_res, c_z] pair representation
            msa_mask: [batch, N_seq, N_res] MSA mask
            pair_mask: [batch, N_res, N_res] pair mask
            gradient_checkpointing: whether to use gradient checkpointing

        Returns:
            m: [batch, N_seq, N_res, c_m] updated MSA representation
            z: [batch, N_res, N_res, c_z] updated pair representation
            s: [batch, N_res, c_s] single representation

        """

        if gradient_checkpointing:
            assert torch.is_grad_enabled()
            m, z = self._forward_blocks_with_gradient_checkpointing(
                m=m,
                z=z,
                msa_mask=msa_mask,
                pair_mask=pair_mask,
            )
        else:
            m, z = self._forward_blocks(
                m=m,
                z=z,
                msa_mask=msa_mask,
                pair_mask=pair_mask,
            )
        s = self.linear(m[:, 0, :, :])
        return m, z, s

    def _forward_blocks(
        self,
        m: torch.Tensor,
        z: torch.Tensor,
        msa_mask: torch.Tensor,
        pair_mask: torch.Tensor,
    ) -> Tuple[torch.Tensor, torch.Tensor]:
        if dap.is_enabled():
            m = dap.scatter(m, dim=1)
            z = dap.scatter(z, dim=1)

        for block in self.blocks:
            m, z = block(m=m, z=z, msa_mask=msa_mask, pair_mask=pair_mask)

        if dap.is_enabled():
            m = dap.gather(m, dim=1)
            z = dap.gather(z, dim=1)

        return m, z

    def _forward_blocks_with_gradient_checkpointing(
        self,
        m: torch.Tensor,
        z: torch.Tensor,
        msa_mask: torch.Tensor,
        pair_mask: torch.Tensor,
    ) -> Tuple[torch.Tensor, torch.Tensor]:
        blocks = [
            partial(
                block,
                msa_mask=msa_mask,
                pair_mask=pair_mask,
            )
            for block in self.blocks
        ]

        if dap.is_enabled():
            m = dap.scatter(m, dim=1)
            z = dap.scatter(z, dim=1)

        for block in blocks:
            m, z = gradient_checkpointing_fn(block, m, z, use_reentrant=True)

        if dap.is_enabled():
            m = dap.gather(m, dim=1)
            z = dap.gather(z, dim=1)

        return m, z
