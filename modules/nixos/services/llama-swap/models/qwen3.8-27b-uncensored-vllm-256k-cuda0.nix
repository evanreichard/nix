# Abliterated body (leminkozey/Qwen3.8-27B-Uncensored-W4A16-AutoRound): same AutoRound
# W4A16 recipe plus this repo's own head requant, so weight size matches the base and the
# pinned 4.90 GiB pool stays valid. `MODEL=` is required - the launcher prefers the base
# model's `-fast` dir otherwise, which would silently serve the base checkpoint.
# Abliteration quality is unmeasured on this stack (syv-ai issue #45: ~100 tok/s warm, a
# 45k needle retrieved, coherent, no refusals); the DFlash2 drafter is shared with the base.
#
# KVarN 4/2-bit KV: the model's full 262,144 max-model-len at 1.04x on this card, one
# request deep, and lossy (GSM8K 95.2% against 96.5% for the bf16 tier) - the tier for
# requests that would not otherwise fit, not for speed.
#
# VISION=1 for the tower the checkpoint carries (333 `model.visual.*` tensors), offloaded
# to pinned host RAM so the pool is unchanged. One image per prompt, 2048 image tokens.
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B Uncensored (KV-KVARN)";
  backend = "vllm-syv";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "262144";
  cmd = backends.qwen38SyvCmd "qwen3.8-27b-uncensored-vllm-256k-cuda0" [
    "CTX=huge"
    "MAX_LEN=262144"
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
