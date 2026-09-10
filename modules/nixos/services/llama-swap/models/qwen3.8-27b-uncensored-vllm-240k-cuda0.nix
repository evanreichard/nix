# KVarN 4/2-bit KV cache (installed into the image at build time): 268,169 tokens of
# pool at 245,760 max-model-len on a 4.90 GiB pin, 2 slots. The deepest context on this
# card by a wide margin, and upstream measures 67 tok/s across a mixed task set and 164
# reproducing a document. The cache is lossy - GSM8K 95.2% against 96.5% for the bf16
# tier - so it is the profile for requests that would not otherwise fit, not for speed.
#
# Abliterated body (leminkozey/Qwen3.8-27B-Uncensored-W4A16-AutoRound): same AutoRound
# W4A16 recipe plus the repo's own head requant, so weight size matches the base and the
# pinned pool constants stay valid (syv-ai issue #45: ~100 tok/s warm, 45k needle
# retrieved, coherent, no refusals). MODEL= is required - the launcher prefers the
# fast variant of the base model otherwise. Abliteration quality is unmeasured on this
# stack; the drafter (DFlash2) is the shared base-model artifact and is unaffected.
{ backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B Uncensored (vLLM, DFlash2, KVarN, 240K, CUDA0)";
  backend = "vllm-syv";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "245760";
  cmd = backends.qwen38SyvCmd "qwen3.8-27b-uncensored-vllm-240k-cuda0" [
    "CTX=huge"
    "MODEL=/app/models/Qwen3.8-27B-Uncensored-W4A16-AutoRound"
  ];
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "reasoning"
    ];
    reasoning = reasoning.qwen38Vllm;
  };
}
