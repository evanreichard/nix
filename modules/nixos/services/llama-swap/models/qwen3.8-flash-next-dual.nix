# https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/tree/main/UD-IQ3_XXS
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 Flash Next 125B-A6B (Dual GPU, UD-IQ3)";
  backend = "llama-cpp";
  placement = "dual";
  macros.ctx = "200000";
  # Placement - The PLE tensor and 24 MoE layers stay resident in RAM. Measured footprint at
  # these flags: 23,841 MiB on CUDA0 (3090), 9,911 MiB on CUDA1 (1080 Ti), ~52 GiB RAM.
  # -ts 82,18 fills the 3090 first because it is the card that decodes fast; the estimator's
  # 85,15 left 3.7 GiB idle on it.
  # Q8_0 KV - Needs llama.cpp >= 0.4.0. The QSA path asserted on Hadamard-rotated quantized
  # caches until #27967; f16 KV at this context costs 2.3 GiB more and buys nothing.
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
