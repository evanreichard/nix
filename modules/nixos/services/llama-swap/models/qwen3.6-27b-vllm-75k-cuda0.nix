# https://github.com/noonghunna/club-3090/tree/master/models/qwen3.6-27b/vllm
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.6 27B (vLLM, 75K, CUDA0)";
  backend = "vllm-club3090";
  placement = "cuda0";
  checkEndpoint = "/v1/models";
  macros.ctx = "75000";
  cmd =
    let
      vllmCmd = ''
        set -e; pip install xxhash pandas scipy -q;
        python3 -m vllm._genesis.patches.apply_all;
        python3 /patches/patch_timings_1acd67a.py;
        exec vllm serve ''${VLLM_ENFORCE_EAGER:+--enforce-eager}
        --served-model-name ''${MODEL_ID}
        --model /root/.cache/huggingface/qwen3.6-27b-autoround-int4
        --quantization auto_round
        --dtype float16
        --tensor-parallel-size 1
        --max-model-len ''${ctx}
        --gpu-memory-utilization 0.97
        --max-num-seqs 1
        --max-num-batched-tokens 2048
        --kv-cache-dtype fp8_e5m2
        --language-model-only
        --trust-remote-code
        --reasoning-parser qwen3
        --enable-auto-tool-choice
        --tool-call-parser qwen3_coder
        --chat-template /templates/chat_template.jinja
        --enable-prefix-caching
        --enable-chunked-prefill
        --speculative-config '{\"method\":\"mtp\",\"num_speculative_tokens\":3}'
        --host 0.0.0.0
        --port 8000
      '';
      vllmCmdFlat = builtins.replaceStrings [ "\n" ] [ " " ] vllmCmd;
    in
    ''
      ${backends.docker} run --rm --device=nvidia.com/gpu=all \
        --name ''${MODEL_ID} \
        --ipc=host \
        -e CUDA_DEVICE_MAX_CONNECTIONS=8 \
        -e CUDA_VISIBLE_DEVICES=0 \
        -e GENESIS_ENABLE_P58_ASYNC_PLACEHOLDER_FIX=1 \
        -e GENESIS_ENABLE_P64_QWEN3CODER_MTP_STREAMING=1 \
        -e GENESIS_ENABLE_P66_CUDAGRAPH_SIZE_FILTER=1 \
        -e GENESIS_ENABLE_P68_AUTO_FORCE_TOOL=1 \
        -e GENESIS_ENABLE_P69_LONG_CTX_TOOL_REMINDER=1 \
        -e GENESIS_ENABLE_P72_PROFILE_RUN_CAP=1 \
        -e GENESIS_ENABLE_P74_CHUNK_CLAMP=1 \
        -e GENESIS_ENABLE_P94=1 \
        -e GENESIS_ENABLE_PN13_CUDA_GRAPH_LAMBDA_ARITY=1 \
        -e GENESIS_ENABLE_PN14_TQ_DECODE_OOB_CLAMP=1 \
        -e GENESIS_ENABLE_PN17_FA2_LSE_CLAMP=1 \
        -e GENESIS_ENABLE_PN19_SCOPED_MAX_SPLIT=1 \
        -e GENESIS_ENABLE_PN59_STREAMING_GDN=1 \
        -e GENESIS_ENABLE_PN8_MTP_DRAFT_ONLINE_QUANT=1 \
        -e GENESIS_P68_P69_LONG_CTX_THRESHOLD_CHARS=50000 \
        -e GENESIS_PROFILE_RUN_CAP_M=4128 \
        -e NCCL_CUMEM_ENABLE=0 \
        -e NCCL_P2P_DISABLE=1 \
        -e OMP_NUM_THREADS=1 \
        -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:512 \
        -e VLLM_ALLOW_LONG_MAX_MODEL_LEN=1 \
        -e VLLM_FLOAT32_MATMUL_PRECISION=high \
        -e VLLM_MARLIN_USE_ATOMIC_ADD=1 \
        -e VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=0 \
        -e VLLM_NO_USAGE_STATS=1 \
        -e VLLM_USE_FLASHINFER_SAMPLER=1 \
        -e VLLM_WORKER_MULTIPROC_METHOD=spawn \
        -e VLLM_ENFORCE_EAGER \
        -v /mnt/ssd/vLLM/Models:/root/.cache/huggingface \
        -v /mnt/ssd/vLLM/Patches/genesis/vllm/_genesis:/usr/local/lib/python3.12/dist-packages/vllm/_genesis:ro \
        -v /mnt/ssd/vLLM/Patches/patch_timings_1acd67a.py:/patches/patch_timings_1acd67a.py:ro \
        -v /mnt/ssd/vLLM/Templates/chat_template-v11.jinja:/templates/chat_template.jinja \
        -p ''${PORT}:8000 \
        --entrypoint /bin/bash \
        vllm/vllm-openai:nightly-1acd67a795ebccdf9b9db7697ae9082058301657 \
        -c "${vllmCmdFlat}"
    '';

  # Cache Bug - On resume from cache, VRAM usage is higher than just generating in real time.

  # -e TRITON_CACHE_DIR=/root/.triton/cache \
  # -v /mnt/ssd/vLLM/Cache/torch_compile:/root/.cache/vllm/torch_compile_cache \
  # -v /mnt/ssd/vLLM/Cache/triton:/root/.triton/cache \

  metadata = {
    tags = [
      "text-generation"
      "coding"
      "reasoning"
    ];
    reasoning = reasoning.qwen36Vllm;
  };
}
