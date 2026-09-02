# rk8v4 stores keys at eight bits and rotated values at four: ~25.6 KiB/token against
# ~33 KiB/token for INT8. It is experimental and lossy - upstream measured a quality
# regression on a coding fixture - so INT8 stays the default for real work.
#
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 27B (NInfer, RotorQuant, 229K, CUDA0)";
  backend = "ninfer";
  placement = "cuda0";
  macros.ctx = "234496";
  env = [
    "CUDA_VISIBLE_DEVICES=0"
  ];
  cmd = ''
    ${backends.ninfer}/bin/ninfer-serve /mnt/ssd/Ninfer/Models/qwen3_8_27b.ninfer \
      --host 127.0.0.1 \
      --port ''${PORT} \
      --model-id qwen3.8-27b-ninfer-rk8v4-229k-cuda0 \
      --max-context ''${ctx} \
      --kv-capacity ''${ctx} \
      --max-concurrency 1 \
      --max-pending-requests 16 \
      --prefill-chunk 1024 \
      --kv-dtype rk8v4 \
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
      "reasoning"
    ];
    reasoning = reasoning.qwen38Ninfer;
  };
}
