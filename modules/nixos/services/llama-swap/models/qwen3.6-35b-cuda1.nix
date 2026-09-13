# https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/tree/main
#
# Pairs With flash-next - 10,946 MiB on the 1080 Ti and ~13 GiB RAM, so it stays resident
# beside qwen3.8-flash-next-cuda0 (23,313 MiB on the 3090, ~37 GiB RAM). Measured together:
# 38.7 tok/s here and 20.9 there, neither degraded. Only simultaneous decode would contend,
# since both draw on the same six cores.
#
# MTP Pays Now - Speculation was a large loss on the pre-AVX2 CPU backend (10.4 against 29.0
# tok/s). With working kernels the draft head wins: 39.0 against 33.4 tok/s at identical
# placement. It costs ~1.1 GiB of VRAM, which is why ncmoe is 28 rather than 26 - at 26 the
# draft context fails in graph_reserve. Needs the MTP-GGUF build, not the base repo's.
#
# Q4_K_M Over IQ4_NL Is Now Marginal - The old 15.3-against-29.0 gap was an artifact of the
# baseline-ISA build. With AVX2 the IQ kernels catch up and IQ4_NL's 4.2 GiB smaller footprint
# buys three GPU layers: 36.6 against 32.6 tok/s unspeculated. Q4_K_M stays for the quality.
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
