# https://huggingface.co/ubergarm/Qwen3.6-27B-GGUF/tree/main
{ pkgs, lib, backends, reasoning }:
{
  name = "Qwen3.6 (27B) (CUDA0, IQ4_KS)";
  backend = "ik-llama-cpp";
  placement = "cuda0";
  macros.ctx = "156000";
  env = [ "CUDA_VISIBLE_DEVICES=0" ];
  cmd = ''
    ${backends.ik-llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-27B-MTP-IQ4_KS.gguf \
      -c ''${ctx} -ctk q8_0 -ctv q8_0 -ngl 99 \
      -mtp --draft-max 4 --draft-p-min 0.75 \
      -muge -mqkv -cram 32768 --ctx-checkpoints 32 \
      --jinja --chat-template-kwargs '{"preserve_thinking":true}'
  '';
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "reasoning"
    ];
    reasoning = reasoning.qwen36IkLlamaCpp;
  };
}
