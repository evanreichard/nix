# https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/tree/main/UD-IQ3_XXS
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 Flash Next 177B-A6B (CUDA0, UD-IQ3)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "163840";
  # One Card, Not Two - The 1080 Ti holds ~7 layers but adds more pipeline latency than those
  # layers cost on the CPU, and every marginal layer it takes is a slow Pascal layer instead
  # of a 3090 one. Dropping it measured 22.5 tok/s against 21.9 dual, and frees CUDA1 for a
  # second resident model. Measured 23,793 MiB on CUDA0, ~34 GiB RAM.
  # Context Is The Lever - ncmoe 32 is the knee: 262K needs ncmoe 35 and falls to ~19.7 tok/s,
  # 64K allows ncmoe 30 for ~25.7. See AGENTS.md for the full matrix.
  # Q8_0 KV - Needs llama.cpp >= 0.4.0; the QSA graph asserted on quantized K caches until
  # #27967, and f16 KV costs 2.3 GiB here for nothing.
  # Vision On The CPU - --mmproj-device none keeps the projector in RAM, so VRAM and text
  # decode are untouched and only requests carrying an image pay (~17 s of CPU ViT).
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.8/Qwen3.8-Flash-Next-UD-IQ3_XXS-00001-of-00003.gguf \
      --mmproj /mnt/ssd/Models/Qwen3.8/Qwen3.8-Flash-Next-mmproj-F16.gguf \
      --mmproj-device none \
      --image-min-tokens 1024 \
      --image-max-tokens 4096 \
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
      -dev CUDA0 \
      -ngl all \
      -ot per_layer_token_embd.weight=CPU \
      -ncmoe 32 \
      -fit off \
      -lm none \
      --cache-reuse 256
  '';

  metadata = {
    tags = [
      "text-generation"
      "coding"
      "reasoning"
      "vision"
    ];
    reasoning = reasoning.qwen38LlamaCpp;
  };
}
