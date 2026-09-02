# https://huggingface.co/unsloth/Qwen3-Coder-Next-GGUF/tree/main
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3 Coder Next 80B (Dual GPU)";
  backend = "llama-cpp";
  placement = "dual";
  macros.ctx = "131072";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3/Qwen3-Coder-Next-UD-Q4_K_XL.gguf \
      -c ''${ctx} \
      --temp 1.0 \
      --top-p 0.95 \
      --min-p 0.01 \
      --top-k 40 \
      -fit off \
      -ncmoe 19 \
      -ts 78,22
  '';

  metadata = {
    tags = [
      "text-generation"
      "coding"
    ];
  };
}
