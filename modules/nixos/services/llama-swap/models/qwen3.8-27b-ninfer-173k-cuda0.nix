# https://huggingface.co/neroued/Qwen3.8-27B-NInfer
#
# All profiles share one artifact; run setup-qwen38-ninfer.sh to fetch it.
# --model-id must equal the llama-swap alias: NInfer rejects requests whose model
# field does not match its public model ID.
#
# Long-Context Profiles - Capacities measured on this 3090 (see README): the C1/MTP3
# startup ceiling is 181,312 tokens INT8 and 239,296 rk8v4, each leaving only ~75 MiB
# free. These sit ~4K tokens below that for ~200 MiB of slack, which model swaps need.
# Both were verified end to end at 60.7 and 56.0 tok/s decode.
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.8 27B (NInfer, 173K, CUDA0)";
  backend = "ninfer";
  placement = "cuda0";
  macros.ctx = "177152";
  env = [
    "CUDA_VISIBLE_DEVICES=0"
  ];
  cmd = ''
    ${backends.ninfer}/bin/ninfer-serve /mnt/ssd/Ninfer/Models/qwen3_8_27b.ninfer \
      --host 127.0.0.1 \
      --port ''${PORT} \
      --model-id qwen3.8-27b-ninfer-173k-cuda0 \
      --max-context ''${ctx} \
      --kv-capacity ''${ctx} \
      --max-concurrency 1 \
      --max-pending-requests 16 \
      --prefill-chunk 1024 \
      --kv-dtype int8 \
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
