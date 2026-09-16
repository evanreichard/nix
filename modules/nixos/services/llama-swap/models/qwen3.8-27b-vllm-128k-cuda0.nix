# int8 per-token-head KV on the Triton backend: the same 5.2 GiB pin holds 136,429 tokens
# instead of 68,605, at 4 slots - 131,072 max-model-len at 1.04x. It buys the context by
# spending prefill (251 s to load a 112k document against FlashAttention's ~112 s), so it
# only pays behind the prefix cache, where turn two costs 5.9 s. A document front-end, not
# a chat default.
#
# Two patches carry the geometry: hybrid-sw-block-promote stops the drafter's five
# sliding-window layers from taking 385 near-empty blocks, and spec-decode-int8-kv lets the
# split-KV verify kernel read the quantized cache.
#
# VISION=1 costs nothing here: VISION_OFFLOAD holds the tower's 0.858 GiB in pinned host
# RAM, so the pool is byte-identical to what it is with VISION=0. Verified in one request -
# a 99,995-token document carrying a marker sentence at 33k and a needle at 67k, plus a
# 396-image-token picture, returned all three at a 248 s TTFT; a byte-identical repeat
# against the cached prefix answered in 4.4 s.
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B (KV-INT8)";
  backend = "vllm-syv";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "131072";
  cmd = backends.qwen38SyvCmd "qwen3.8-27b-vllm-128k-cuda0" [
    "CTX=long"
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
