# Muse-Glimmer 30B with DFlash speculative decoding
{ pkgs, lib, backends, reasoning }:
{
  name = "Muse-Glimmer 30B (VL, CUDA0, DFlash)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "262144";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      --model /mnt/ssd/Models/Muse/Muse-Glimmer-30B-UD-Q4_K_XL.gguf \
      --mmproj /mnt/ssd/Models/Muse/Muse-Glimmer-30B-mmproj-kquant.gguf \
      --spec-draft-model /mnt/ssd/Models/Muse/Muse-Glimmer-30B-DFlash-kquant.gguf \
      --spec-draft-ngl 999 \
      --spec-draft-n-max 15 \
      --spec-type draft-dflash \
      -c 262144 \
      --override-kv muse-glimmer.context_length=int:262144,dflash.context_length=int:262144 \
      -ngl 999 \
      -fit off \
      --parallel 1 \
      --flash-attn on \
      --no-warmup \
      --cache-type-k f16 \
      --cache-type-v f16 \
      --temp 1.0 \
      --top-p 0.95 \
      --top-k 64 \
      --reasoning-preserve \
      --jinja \
      --host 127.0.0.1 \
      -dev CUDA0
  '';
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "vision"
      "reasoning"
    ];
    reasoning = reasoning.museGlimmerLlamaCpp;
  };
}
