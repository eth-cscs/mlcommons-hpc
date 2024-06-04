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

import torch
import torch.nn as nn
import torch.nn.functional as F

from apex.contrib.openfold_triton import LayerNormSmallShapeOptImpl


class LayerNorm(nn.Module):
    """Layer Normalization module.

    Supplementary '1.11.4 Parameters initialization': Layer normalization.

    Args:
        in_channels: Last dimension of the input tensor.
        eps: A value added to the denominator for numerical stability.

    """

    def __init__(
        self,
        in_channels: int,
        eps: float = 1e-5,
    ) -> None:
        super(LayerNorm, self).__init__()
        self.normalized_shape = (in_channels,)
        self.eps = eps
        self.weight = nn.Parameter(torch.ones(in_channels))
        self.bias = nn.Parameter(torch.zeros(in_channels))
        self._ln_eager_func = F.layer_norm
        self._ln_inductor_func = torch.compile(F.layer_norm)
        self._ln_triton_func = LayerNormSmallShapeOptImpl.apply

    def _should_use_triton_kernels(self, x: torch.Tensor) -> bool:
        # These two most common layer-norm shapes in open-fold are well handled by Triton kernels.
        # Applying Triton kernels to other shapes will mysteriously degrade convergence.
        # TODO(@davidli): Look back for convergence issue if need to be.
        ln_triton_shapes = (
            (256, 128),
            (256, 256),
        )
        ln_triton_dim = 4
        return (
            self.training
            and x.dim() == ln_triton_dim
            and x.shape[-2:] in ln_triton_shapes
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        if self._should_use_triton_kernels(x):
            return self._ln_triton_func(
                x, self.normalized_shape, self.weight, self.bias, self.eps
            )
        elif self.training:
            return self._ln_inductor_func(
                x, self.normalized_shape, self.weight, self.bias, self.eps
            )
        else:
            return self._ln_eager_func(
                x, self.normalized_shape, self.weight, self.bias, self.eps
            )
