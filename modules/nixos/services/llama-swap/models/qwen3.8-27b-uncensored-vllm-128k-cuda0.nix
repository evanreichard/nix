# Abliterated body (leminkozey/Qwen3.8-27B-Uncensored-W4A16-AutoRound): same AutoRound
# W4A16 recipe plus this repo's own head requant, so weight size matches the base and the
# pinned pool constants stay valid. `MODEL=` is required - the launcher prefers the base
# model's `-fast` dir otherwise. Abliteration quality is unmeasured on this stack (syv-ai
# issue #45); the DFlash2 drafter is shared with the base profiles.
#
# int8 per-token-head KV on the Triton backend: 136,429 tokens at 131,072 max-model-len,
# 4 slots. Prefill-heavy (251 s for a 112k document), so it wants the prefix cache.
#
# VISION=1 for the tower the checkpoint carries (333 `model.visual.*` tensors), offloaded
# to pinned host RAM so the pool is unchanged. One image per prompt, 2048 image tokens.
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B Uncensored (KV-INT8)";
  backend = "vllm-hyperqwen";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "131072";
  cmd = backends.hyperQwenCmd "qwen3.8-27b-uncensored-vllm-128k-cuda0" [
    "CTX=long"
    "VISION=1"
    "MODEL=/app/models/Qwen3.8-27B-Uncensored-W4A16-AutoRound"
  ];
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "vision"
      "reasoning"
      "uncensored"
    ];
    reasoning = reasoning.qwen38Vllm;
  };
}
