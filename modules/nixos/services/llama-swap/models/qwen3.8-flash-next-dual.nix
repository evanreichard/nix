# https://huggingface.co/unsloth/Qwen3.8-Flash-Next-GGUF/tree/main/UD-IQ4_XS
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 Flash Next 125B-A6B (Dual GPU, UD-IQ4)";
  backend = "llama-cpp";
  placement = "dual";
  macros.ctx = "120000";
  # Placement - The PLE tensor and 30 MoE layers stay resident in RAM. The measured footprint is 65 GiB RAM, 23,124 MiB on CUDA0, and 9,733 MiB on CUDA1.
  # F16 KV - PR #27742's QSA path still asserts on Hadamard-rotated quantized KV caches.
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.8/Qwen3.8-Flash-Next-UD-IQ4_XS-00001-of-00003.gguf \
      -c ''${ctx} \
      -np 1 \
      --temp 1.0 \
      --top-p 0.95 \
      --top-k 20 \
      --min-p 0.0 \
      --presence-penalty 0.0 \
      --repeat-penalty 1.0 \
      -fa on \
      -ctk f16 \
      -ctv f16 \
      -dev CUDA0,CUDA1 \
      -sm layer \
      -ts 85,15 \
      -ngl all \
      -ot per_layer_token_embd.weight=CPU \
      -ncmoe 30 \
      -fit off \
      -lm none \
      --chat-template-kwargs "{\"preserve_thinking\": true}"
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
