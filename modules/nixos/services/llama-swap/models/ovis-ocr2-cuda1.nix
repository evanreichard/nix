# https://huggingface.co/Abiray/OvisOCR2-GGUF/tree/main
#
# Same geometry as ovis-ocr2-cuda0; verified end to end here at 8 concurrent pages,
# which is why the 3090 copy needs no separate sizing.
{ pkgs, lib, backends, reasoning }:
{
  name = "OvisOCR2 0.8B (OCR, 100K, CUDA1)";
  backend = "llama-cpp";
  placement = "cuda1";
  macros.ctx = "102400";
  env = [ "CUDA_VISIBLE_DEVICES=1" ];
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
