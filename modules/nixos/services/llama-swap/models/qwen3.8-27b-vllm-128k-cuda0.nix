# int8 per-token-head KV on the Triton backend: the same 5.2 GiB pool holds 136,429
# tokens instead of 69,758, at 4 slots. It buys the context by spending prefill - 251 s
# to load a 112k document against FlashAttention's ~112 s - so it only pays behind the
# prefix cache, where turn two costs 5.9 s. A document front-end, not a chat default.
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.8 27B (vLLM, DFlash2, 128K, CUDA0)";
  backend = "vllm-syv";
  placement = "cuda0";
  healthCheckTimeout = 900;
  useModelName = "qwen3.8-27b";
  macros.ctx = "131072";
  cmd = backends.qwen38SyvCmd "qwen3.8-27b-vllm-128k-cuda0" [ "CTX=long" ];
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "reasoning"
    ];
    reasoning = reasoning.qwen38Vllm;
  };
}
