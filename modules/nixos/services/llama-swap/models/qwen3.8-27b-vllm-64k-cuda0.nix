# bf16 KV on FlashAttention: the lossless tier and the fastest one - 68,605 tokens at
# 65,536 max-model-len, 8 slots, 129 tok/s decode at 15.6k. It is also the only tier the
# split-KV verify kernel patches (SPEC_ATTN stays on here), and the geometry upstream
# verified vision against.
#
# VISION=1 keeps the tower, which every profile here does - without it the launcher passes
# --language-model-only. One image per prompt and a 2048-image-token pixel cap, both
# overridable from EXTRA_ARGS. The tower's 0.858 GiB stays in pinned host RAM
# (VISION_OFFLOAD, on by default) and is copied to the GPU per module: 0.85 GiB of the
# ~1.1 GiB transient margin, without which graph capture OOMs allocating the 960 MiB
# split-KV verify buffer. The KV pool is byte-identical to what it is with VISION=0.
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B (KV-BF16)";
  backend = "vllm-syv";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "65536";
  cmd = backends.qwen38SyvCmd "qwen3.8-27b-vllm-64k-cuda0" [
    "CTX=fast"
    "VISION=1"
  ];
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "vision"
      "reasoning"
    ];
    reasoning = reasoning.qwen38Vllm;
  };
}
