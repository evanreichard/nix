# https://huggingface.co/Abiray/OvisOCR2-GGUF/tree/main
#
# Page-Parsing Profile - 0.8B Qwen3.5 derivative that transcribes a full page into
# Markdown with LaTeX formulas and HTML tables; it has no coding or chat use.
# Eight 12.8K slots: a 200 DPI page plus its transcription fits inside one slot, and
# --image-min-tokens 1024 is upstream's floor for Qwen-VL image handling. Measured
# 2.7 GiB total at this geometry, so it is a filler model rather than a resident one.
{ pkgs, lib, backends, reasoning }:
{
  name = "OvisOCR2 0.8B (OCR, 100K, CUDA0)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "102400";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Vision/OvisOCR2-Q8_0.gguf \
      --mmproj /mnt/ssd/Models/Vision/OvisOCR2-mmproj-F16.gguf \
      -c ''${ctx} \
      --parallel 8 \
      --image-min-tokens 1024 \
      --temp 0.0 \
      --top-p 1.0 \
      --no-warmup \
      -fit off \
      -dev CUDA0
  '';
  metadata = {
    tags = [
      "text-generation"
      "vision"
    ];
  };
}
