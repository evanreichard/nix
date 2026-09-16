# https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/tree/main
#
# IQ4_XS is the fastest measured IQ4 candidate at the native 262,144-token context on CUDA1:
# 38.9 tok/s with MTP n=2 p=0.5 (ncmoe 30), 38.2 at n=3 p=0, 35.0 direct. ncmoe 29 + MTP fails
# the first decode with a 296 MiB compute-buffer OOM, so MTP keeps 30.
#
# Pairs With flash-next - ~11 GiB VRAM and ~14 GiB RAM, so both stay resident; only simultaneous
# decode contends, over the same 6 cores. Deep-context check at 212K tokens: 151.6 tok/s prefill,
# 23.2 tok/s decode, 7 MiB free after the run - full-depth requests approach the VRAM ceiling.
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.6 35B (UD-IQ4_XS)";
  backend = "llama-cpp";
  placement = "cuda1";
  macros.ctx = "262144";
  env = [ "CUDA_VISIBLE_DEVICES=1" ];
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf \
      -c ''${ctx} \
      -np 1 \
      --temp 0.6 \
      --top-p 0.95 \
      --top-k 20 \
      --min-p 0.0 \
      --presence-penalty 0.0 \
      -ctk q8_0 \
      -ctv q8_0 \
      --spec-type draft-mtp \
      --spec-draft-n-max 2 \
      --spec-draft-p-min 0.5 \
      -dev CUDA0 \
      -ngl all \
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
    reasoning = reasoning.qwen36LlamaCpp;
  };
}
