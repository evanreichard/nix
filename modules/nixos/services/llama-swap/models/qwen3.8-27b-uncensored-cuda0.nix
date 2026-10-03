# https://huggingface.co/JonathanColetti/Qwen3.8-27B-Uncensored-GGUF
# IQ4_XS with the embedded Qwen3.8 MTP head. On the RTX 3090, q8 KV passed a
# 90%-filled context probe at 194,560 tokens; 196,608 failed during startup.
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 27B Uncensored (IQ4_XS, Q8 KV)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "194560";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.8/Qwen3.8-27B-Uncensored-IQ4_XS.gguf \
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
      "uncensored"
    ];
    reasoning = reasoning.qwen38LlamaCpp;
  };
}
