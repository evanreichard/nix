# https://github.com/syv-ai/qwen38-27b-rtx3090
#
# Patched vLLM 0.27.1 with the DFlash2 block drafter: seven drafts proposed in one
# non-autoregressive pass instead of MTP's four chained ones, plus lookup drafting that
# fills the verify block straight from the request's own context. Upstream measures 133
# tok/s at C1 on chat prompts and up to 382 where the answer quotes the prompt, against
# 46 tok/s unspeculated. Speculation is exact - it samples the same distribution.
#
# One Stream, Not One Seat - a resident request reserves k+1 recurrent-state slots
# (~0.88 GiB) out of the same pinned pool before it holds a token of context, so decode
# halves at two concurrent streams and quarters at four. MAX_SEQS is an admission limit,
# not a residency one; these profiles keep the launcher's own slot defaults.
#
# bf16 KV on FlashAttention, the only backend the split-KV verify kernel patches, and the
# only lossless one here. 8 slots, 5.2 GiB pinned pool holding 69,758 tokens.
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B (vLLM, DFlash2, 64K, CUDA0)";
  backend = "vllm-syv";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "65536";
  cmd = backends.qwen38SyvCmd "qwen3.8-27b-vllm-64k-cuda0" [ "CTX=fast" ];
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "reasoning"
    ];
    reasoning = reasoning.qwen38Vllm;
  };
}
