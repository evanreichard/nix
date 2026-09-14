# https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/tree/main/UD-IQ3_XXS
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 Flash Next 177B-A6B (CUDA0, UD-IQ3)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "262144";
  # One Card - The 1080 Ti's marginal layers are Pascal layers and its extra hop costs more
  # than they save for decode, and CUDA1 stays free for a second model. AGENTS.md has the
  # context/speed matrix and the dual-GPU alternative, which is 1.6x on prefill.
  # -ub 1024 - Prefill streams CPU-resident experts over a gen3 x4 link, so a wider ubatch
  # amortises the transfer: 151 tok/s against 93. Its buffer costs two MoE layers (ncmoe 37).
  # Q8_0 KV needs llama.cpp >= 0.4.0 (#27967). --mmproj-device none keeps the projector in
  # RAM, so vision costs no VRAM and only image requests pay.
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
      -ncmoe 37 \
      -ub 1024 \
      -b 2048 \
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
