# Vision costs ~1.83 GiB of fixed reservation (encoder plus the media request-transient
# buffer) and ~282 MiB of extra weights, independent of KV dtype, but per-token KV is
# unchanged. Ceilings are 118,336 int8 and 156,224 rk8v4; upstream's launcher ships 32K
# because it targets a stock 24 GiB card conservatively, not because vision caps context.
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 27B (NInfer, VL, 112K, CUDA0)";
  backend = "ninfer";
  placement = "cuda0";
  macros.ctx = "114688";
  env = [
    "CUDA_VISIBLE_DEVICES=0"
  ];
  cmd = ''
    ${backends.ninfer}/bin/ninfer-serve /mnt/ssd/Ninfer/Models/qwen3_8_27b.ninfer \
      --host 127.0.0.1 \
      --port ''${PORT} \
      --model-id qwen3.8-27b-ninfer-112k-vl-cuda0 \
      --max-context ''${ctx} \
      --kv-capacity ''${ctx} \
      --max-concurrency 1 \
      --max-pending-requests 8 \
      --prefill-chunk 512 \
      --kv-dtype int8 \
      --default-max-tokens 1024 \
      --vision \
      --spec mtp \
      --draft-tokens 3 \
      --lm-head-draft \
      --preserve-thinking \
      --cors
  '';
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "vision"
      "reasoning"
    ];
    reasoning = reasoning.qwen38Ninfer;
  };
}
