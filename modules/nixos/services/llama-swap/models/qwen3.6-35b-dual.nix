# https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/tree/main
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.6 35B (Dual GPU, UD-Q6)";
  backend = "llama-cpp";
  placement = "dual";
  # macros.ctx = "215000";
  # -ctk q8_0 \
  # -ctv q8_0 \
  macros.ctx = "131072";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-35B-A3B-UD-Q6_K.gguf \
      -c ''${ctx} \
      -np 4 -kvu \
      --temp 0.6 \
      --top-p 0.95 \
      --top-k 20 \
      --min-p 0.00 \
      --presence-penalty 0.0 \
      --spec-type draft-mtp \
      --spec-draft-n-max 3 \
      -dev CUDA0,CUDA1 \
      -fit off \
      -ts 72,28 \
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
