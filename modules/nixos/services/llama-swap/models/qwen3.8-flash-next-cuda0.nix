# https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/tree/main/UD-IQ3_XXS
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 Flash Next 125B-A6B (Dual GPU, UD-IQ3)";
  backend = "llama-cpp";
  placement = "dual";
  macros.ctx = "200000";
  # Placement - The PLE tensor and 24 MoE layers stay resident in RAM (~52 GiB). Under load
  # the 3090 peaks at 24,069 MiB and the 1080 Ti at 10,093; -ts 82,18 fills the fast card
  # first, which the estimator's 85,15 does not. Measured 7.9 tok/s decode, 144 tok/s prefill.
  # Decode is CPU-bound at ~4.3 ms per CPU-resident MoE layer - see AGENTS.md before retuning,
  # k-quants and thread count were both tried and lost.
  # Q8_0 KV - Needs llama.cpp >= 0.4.0; the QSA graph asserted on quantized K caches until
  # #27967, and f16 KV at this context costs 2.3 GiB that is worth two GPU layers.
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.8/Qwen3.8-Flash-Next-UD-IQ3_XXS-00001-of-00003.gguf \
      -c ''${ctx} \
      -np 1 \
      --temp 1.0 \
      --top-p 0.95 \
      --top-k 20 \
      --min-p 0.0 \
      --presence-penalty 0.0 \
      --repeat-penalty 1.0 \
      -fa on \
      -ctk q8_0 \
      -ctv q8_0 \
      -dev CUDA0,CUDA1 \
      -sm layer \
      -ts 82,18 \
      -ngl all \
      -ot per_layer_token_embd.weight=CPU \
      -ncmoe 24 \
      -fit off \
      -lm none \
      --cache-reuse 256
  '';

  metadata = {
    tags = [
      "text-generation"
      "coding"
      "reasoning"
    ];
    reasoning = reasoning.qwen38LlamaCpp;
  };
}
