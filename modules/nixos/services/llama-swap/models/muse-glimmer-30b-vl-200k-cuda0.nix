# Batch Document Transcription Profile - Four slots of 50K, sized for ~5 page jobs
# (a page saturates the encoder at ~4K tokens, so 5 pages is ~20K).
#
# Measured on this 3090: KV costs 13.25 KiB/token, because only 13 of 52 layers are full
# attention (sliding_window_pattern=4); the rest are capped at the 2048 window. The real
# ceiling is a ~1.9 GiB mmproj compute buffer allocated lazily on the first image, which
# is why 327680 starts up clean and then OOMs on the first request. That buffer is
# per-context rather than per-slot, so --parallel 4 costs almost nothing over 1.
# 262144 fits but peaks at 23.7 GiB; 200000 trades unused depth for ~1.3 GiB of slack.
{ pkgs, lib, backends, reasoning }:
{
  name = "Muse-Glimmer 30B (VL, 200K, CUDA0, DFlash)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "200000";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      --model /mnt/ssd/Models/Muse/Muse-Glimmer-30B-UD-Q4_K_XL.gguf \
      --mmproj /mnt/ssd/Models/Muse/Muse-Glimmer-30B-mmproj-kquant.gguf \
      --spec-draft-model /mnt/ssd/Models/Muse/Muse-Glimmer-30B-DFlash-kquant.gguf \
      --spec-draft-ngl 999 \
      --spec-draft-n-max 15 \
      --spec-type draft-dflash \
      -c ''${ctx} \
      --override-kv muse-glimmer.context_length=int:''${ctx},dflash.context_length=int:''${ctx} \
      -ngl 999 \
      -fit off \
      --parallel 4 \
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
