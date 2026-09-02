# https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/tree/main
#
# Q4_K_M Over IQ4_NL - Only 22 of 48 layers fit on the 1080 Ti, so half the experts run on
# the CPU, where IQ4_NL's lookup-table dequant dominates: it measured 15.3 tok/s against
# 29.0 tok/s for the physically larger Q4_K_M under identical placement. Decode is CPU-bound
# at roughly 26 GB/s of the ~45 GB/s this DDR4 sustains, so spending bandwidth to save CPU
# cycles is the correct trade on Pascal.
#
# No Speculation - Verification activates the union of experts across the entire draft, so
# each drafted token multiplies CPU-side expert reads. MTP measured 10.4 tok/s and n-gram at
# its default draft length 18.7 tok/s, both far below plain decode.
#
# ncmoe 26 - Leaves ~490 MiB spare at 128K. Denser placements gain ~2% and approach the
# ~300 MiB floor where cuBLAS failed to allocate its workspace during testing.
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.6 35B (CUDA1, UD-Q4)";
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
      -dev CUDA0 \
      -ngl all \
      -ncmoe 26 \
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
