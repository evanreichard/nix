# https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF/tree/main
{ pkgs
, lib
, backends
, reasoning
,
}:
{
  name = "Gemma 4 26B (VL, CUDA0)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "196608";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Gemma/gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf \
      --mmproj /mnt/ssd/Models/Gemma/mmproj-BF16_gemma-4-26B-A4B-it-UD-Q4_K_XL.gguf \
      -c ''${ctx} \
      --parallel 1 \
      --spec-type ngram-mod \
      --spec-ngram-mod-n-match 24 \
      --spec-ngram-mod-n-min 48 \
      --spec-ngram-mod-n-max 64 \
      --temp 1.0 \
      --top-k 64 \
      --top-p 0.95 \
      --no-warmup \
      --jinja \
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
