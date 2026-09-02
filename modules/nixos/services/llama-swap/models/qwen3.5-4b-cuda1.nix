# https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/tree/main
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.5 4B (CUDA1)";
  backend = "llama-cpp";
  placement = "cuda1";
  macros.ctx = "131072";
  env = [ "CUDA_VISIBLE_DEVICES=1" ];
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.5/Qwen3.5-4B-IQ4_XS.gguf \
      -c ''${ctx} \
      --temp 0.6 \
      --top-p 0.95 \
      --top-k 20 \
      --min-p 0.0 \
      -fit off \
      -dev CUDA0
  '';
  metadata = {
    tags = [
      "text-generation"
      "coding"
    ];
  };
}
