# https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/tree/main
#
# Pairs With flash-next - 10,946 MiB and ~13 GiB RAM, so both stay resident; measured together
# at 38.7 tok/s here and 20.9 there. Only simultaneous decode contends, over the same 6 cores.
#
# MTP - The draft head wins on an AVX2 backend (39.0 against 33.4) after losing badly without
# one. Needs the MTP-GGUF build and ~1.1 GiB for the draft context, hence ncmoe 28, not 26.
#
# Q4_K_M holds for quality only: IQ4_NL is 4.2 GiB smaller, buys three GPU layers and measures
# 36.6 against 32.6 unspeculated.
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.6 35B (CUDA1, UD-Q4, MTP)";
  backend = "llama-cpp";
  placement = "cuda1";
  macros.ctx = "131072";
  env = [ "CUDA_VISIBLE_DEVICES=1" ];
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf \
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
      --spec-draft-n-max 3 \
      -dev CUDA0 \
      -ngl all \
      -ncmoe 28 \
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
