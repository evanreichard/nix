{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 27B (NInfer, RotorQuant, VL, 148K, CUDA0)";
  backend = "ninfer";
  placement = "cuda0";
  macros.ctx = "151552";
  env = [
    "CUDA_VISIBLE_DEVICES=0"
  ];
  cmd = ''
    ${backends.ninfer}/bin/ninfer-serve /mnt/ssd/Ninfer/Models/qwen3_8_27b.ninfer \
      --host 127.0.0.1 \
      --port ''${PORT} \
      --model-id qwen3.8-27b-ninfer-rk8v4-148k-vl-cuda0 \
      --max-context ''${ctx} \
      --kv-capacity ''${ctx} \
      --max-concurrency 1 \
      --max-pending-requests 8 \
      --prefill-chunk 512 \
      --kv-dtype rk8v4 \
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
