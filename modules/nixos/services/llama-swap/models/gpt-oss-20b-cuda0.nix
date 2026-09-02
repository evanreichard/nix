# https://huggingface.co/mradermacher/gpt-oss-20b-heretic-v2-i1-GGUF/tree/main
{ pkgs, lib, backends, reasoning }:
{
  name = "GPT OSS 20B (CUDA0)";
  backend = "llama-cpp";
  placement = "cuda0";
  macros.ctx = "131072";
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/GPT-OSS/gpt-oss-20b-heretic-v2.i1-MXFP4_MOE.gguf \
      -c ''${ctx} \
      --temp 1.0 \
      --top-p 1.0 \
      --top-k 40 \
      -dev CUDA0
  '';
  metadata = {
    tags = [ "text-generation" ];
  };
}
