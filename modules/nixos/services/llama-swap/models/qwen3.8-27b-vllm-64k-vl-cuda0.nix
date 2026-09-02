# VISION=1 keeps the tower the other profiles drop with --language-model-only, capped at
# one image and 2048 image tokens per prompt because vLLM profiles the encoder at the
# largest image it will accept and that peak comes out of the KV pool. The tower's
# weights stay in pinned host RAM (VISION_OFFLOAD, on by default): 0.85 GiB of the ~1.1
# GiB transient margin, without which graph capture OOMs allocating the verify buffer.
# bf16 KV at 64K - the geometry upstream verified vision against.
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B (vLLM, DFlash2, VL, 64K, CUDA0)";
  backend = "vllm-syv";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "65536";
  cmd = backends.qwen38SyvCmd "qwen3.8-27b-vllm-64k-vl-cuda0" [
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
