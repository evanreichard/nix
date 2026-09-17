# KVarN 4/2-bit KV cache (installed into the image at build time): 272,781 tokens of pool
# on a 4.90 GiB pin, which is the model's full 262,144 max-model-len at 1.04x - one
# request deep, and the deepest context on this card by a wide margin. Measured here with
# a 239,932-token needle at 50% depth: 384 s to first token (~626 tok/s prefill, KVarN's
# prefill path is bounded, so this is the tier that reaches 256k at all) and 12.2 tok/s
# decode at that depth.
#
# The cache is lossy - GSM8K 95.2% against 96.5% for the bf16 tier - so it is the profile
# for requests that would not otherwise fit, not for speed. int4_per_token_head is not the
# higher-capacity alternative it looks like: at the same pin it resolves 268,537 tokens
# (1.02x) against KVarN's 272,781, and costs about twice KVarN's perplexity (+0.3% against
# +0.16%).
#
# VISION=1 costs nothing here: VISION_OFFLOAD holds the tower's 0.858 GiB in pinned host
# RAM, so the pool is byte-identical to what it is with VISION=0. Verified in one request -
# a 200,369-token prompt (a 200k document with a marker at 100k depth, plus a
# 396-image-token picture) returned both markers at a 294 s TTFT.
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B (KV-KVARN)";
  backend = "vllm-hyperqwen";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "262144";
  cmd = backends.hyperQwenCmd "qwen3.8-27b-vllm-256k-cuda0" [
    "CTX=huge"
    "MAX_LEN=262144"
    "VISION=1"
    # Same single-stream limit as the uncensored twin: the pool holds one
    # full-length request, and two resident streams OOM-killed the engine in
    # KVarN's decode path (2026-09-17, 174k continuation). A second request queues.
    "MAX_SEQS=1"
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
