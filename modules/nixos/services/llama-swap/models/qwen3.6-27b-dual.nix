# https://huggingface.co/unsloth/Qwen3.6-27B-GGUF-MTP/tree/main
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.6 27B (Dual GPU, UD-Q6)";
  backend = "llama-cpp";
  placement = "dual";
  macros.ctx = "120000";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-27B-UD-Q6_K_XL.gguf \
      -c ''${ctx} \
      -np 4 -kvu \
      --temp 0.6 \
      --top-p 0.95 \
      --top-k 20 \
      --min-p 0.00 \
      --presence-penalty 0.0 \
      -ctk q8_0 \
      -ctv q8_0 \
      --spec-type draft-mtp \
      --spec-draft-n-max 3 \
      -dev CUDA0,CUDA1 \
      -ts 73,27 \
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
