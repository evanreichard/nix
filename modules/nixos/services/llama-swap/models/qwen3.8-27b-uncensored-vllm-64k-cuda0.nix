# Abliterated body (leminkozey/Qwen3.8-27B-Uncensored-W4A16-AutoRound): the same AutoRound
# W4A16 recipe plus this repo's own head requant, so weight size matches the base and every
# tier's pool constants stay valid. `MODEL=` is required - the launcher prefers the base
# model's `-fast` dir otherwise, which would silently serve the wrong checkpoint.
#
# SPEC=dflash2 is kept: the DFlash2 drafter is a separate directory shared with the base
# profiles, and the checkpoint's author skipped `quant_mtp.py`/`build_draft_vocab.py`, so
# the int8 MTP path would be slower. Abliteration quality is unmeasured on this stack
# (syv-ai issue #45 reports ~100 tok/s warm, a 45k needle retrieved, coherent output, no
# refusals).
#
# bf16 KV on FlashAttention - the lossless tier and the fastest one: 68,605 tokens at
# 65,536 max-model-len, 8 slots, split-KV verify attention on. One image per prompt, 2048
# image tokens; the tower's 0.858 GiB stays in pinned host RAM via VISION_OFFLOAD.
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B Uncensored (KV-BF16)";
  backend = "vllm-hyperqwen";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "65536";
  cmd = backends.hyperQwenCmd "qwen3.8-27b-uncensored-vllm-64k-cuda0" [
    "CTX=fast"
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
