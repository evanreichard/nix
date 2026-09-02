# https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/tree/main
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.6 35B (CUDA0, UD-IQ4)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "262144";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-35B-A3B-UD-IQ4_NL.gguf \
      -c ''${ctx} \
      -np 2 -kvu \
      --temp 0.6 \
      --top-p 0.95 \
      --top-k 20 \
      --min-p 0.0 \
      --presence-penalty 0.0 \
      -ctk q8_0 \
      -ctv q8_0 \
      --spec-type draft-mtp \
      --spec-draft-n-max 3 \
      -dev CUDA0 \
      -fit off \
      --chat-template-kwargs "{\"preserve_thinking\": true}"
  '';
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "reasoning"
    ];
    reasoning = reasoning.qwen36LlamaCpp;
  };
}
