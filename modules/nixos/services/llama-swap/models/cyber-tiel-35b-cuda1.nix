# https://huggingface.co/peculiar-ragdoll/Cyber-Tiel-Coder-35B-A3B-GGUF-MTP/tree/main
#
# Abliterated, cyber-tuned Qwen3.6-35B-A3B derivative (Ornith-1.5 base) with a grafted MTP head
# at block 40 and its own BF16 vision projector. Mirrors qwen3.6-35b-cuda1: same IQ4_XS tier,
# 262,144-token context, Q8 KV, MTP n=2 p=0.5. The 861 MiB projector stays on-card, which costs
# two expert layers (-ncmoe 32 vs 30, ~2 tok/s measured). MTP numbers at ncmoe 30: 35.7 tok/s
# with n=1, 35.1 with n=2 p=0.5, 35.0 direct; n=4 collapses to 33.4. On-card loads at
# 11,091/11,264 MiB. Deep-context verified at a 212,726-token prompt: no OOM, 151.7 tok/s
# prefill, 14.7 tok/s decode, and VRAM sits pinned at 3 MiB free while decoded - the depth
# buffers substitute for the workspace, then restore. Sustained short requests after the
# deep run measured the usual 33.9 tok/s.
#
# MTP head constraint from upstream: never -ncmoe 41 (the head is block 40 and drafts every
# decode step); 40 is the useful maximum, 30 keeps ~1.8 GiB of headroom.
#
# Abliterated model: 0% refusal on HarmBench. Upstream insists on OS-level sandboxing.
{ pkgs, lib, backends, reasoning }:
{
  name = "CyberTiel Coder 35B (CUDA1, UD-IQ4, MTP, 262K)";
  backend = "llama-cpp";
  placement = "cuda1";
  macros.ctx = "262144";
  env = [ "CUDA_VISIBLE_DEVICES=1" ];
  cmd = ''
    ${backends.llama-cpp}/bin/llama-server \
      --port ''${PORT} \
      -m /mnt/ssd/Models/Qwen3.6/Cyber-Tiel-Coder-35B-A3B-MTP-UD-IQ4_XS.gguf \
      --mmproj /mnt/ssd/Models/Qwen3.6/mmproj-BF16.gguf \
      -c ''${ctx} \
      -np 1 \
      --jinja \
      --temp 0.6 \
      --top-p 0.95 \
      --top-k 20 \
      --min-p 0.0 \
      --presence-penalty 0.0 \
      -ctk q8_0 \
      -ctv q8_0 \
      --spec-type draft-mtp \
      --spec-draft-n-max 2 \
      --spec-draft-p-min 0.5 \
      -dev CUDA0 \
      -ngl all \
      -ncmoe 32 \
      -fit off \
      -lm none \
      --chat-template-kwargs "{\"preserve_thinking\": true}"
  '';
  metadata = {
    tags = [
      "text-generation"
      "coding"
      "reasoning"
      "vision"
      "uncensored"
    ];
    reasoning = reasoning.qwen36LlamaCpp;
  };
}
