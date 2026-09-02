# https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/tree/main
#
# Document Transcription Profile - Shares the IQ4_NL weights with qwen3.6-35b-cuda0 and
# adds only the 899 MiB F16 projector. Context is sized for a ~5 page batch (~4K image
# tokens per 200 DPI page plus LaTeX output and thinking), which leaves enough room for
# f16 KV; quantized KV is avoided here because dense math is where it visibly degrades.
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.6 35B (VL, 64K, CUDA0)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "65536";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-35B-A3B-UD-IQ4_NL.gguf \
      --mmproj /mnt/ssd/Models/Qwen3.6/Qwen3.6-35B-A3B-mmproj-F16.gguf \
      -c ''${ctx} \
      --parallel 1 \
      --temp 0.6 \
      --top-p 0.95 \
      --top-k 20 \
      --min-p 0.0 \
      --presence-penalty 0.0 \
      --cache-type-k f16 \
      --cache-type-v f16 \
      --spec-type draft-mtp \
      --spec-draft-n-max 3 \
      -dev CUDA0 \
      -fit off \
      --chat-template-kwargs "{\"preserve_thinking\": true}"
  '';
  metadata = {
    tags = [
      "text-generation"
      "vision"
      "reasoning"
    ];
    reasoning = reasoning.qwen36LlamaCpp;
  };
}
