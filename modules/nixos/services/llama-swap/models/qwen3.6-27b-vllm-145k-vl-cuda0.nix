# https://github.com/noonghunna/club-3090/tree/master/models/qwen3.6-27b/vllm
{ pkgs, lib, backends, reasoning }:
backends.dockerModel {
  name = "Qwen3.6 27B (vLLM, 145K, VL, CUDA0)";
  backend = "vllm-club3090";
  placement = "cuda0";
  checkEndpoint = "/v1/models";
  macros.ctx = "145000";
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
        --gpu-memory-utilization 0.95
        --max-num-seqs 1
        --max-num-batched-tokens 4128
        --kv-cache-dtype turboquant_3bit_nc
        --trust-remote-code
        --reasoning-parser qwen3
        --enable-auto-tool-choice
        --tool-call-parser qwen3_coder
        --enable-prefix-caching
        --enable-chunked-prefill
        --no-scheduler-reserve-full-isl
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
        -e GENESIS_BUFFER_MODE=shared \
        -e GENESIS_ENABLE_P100=1 \
        -e GENESIS_ENABLE_P101=1 \
        -e GENESIS_ENABLE_P103=1 \
        -e GENESIS_ENABLE_P15B_FA_VARLEN_CLAMP=1 \
        -e GENESIS_ENABLE_P38B_COMPILE_SAFE=1 \
        -e GENESIS_ENABLE_P4=1 \
        -e GENESIS_ENABLE_P58_ASYNC_PLACEHOLDER_FIX=1 \
        -e GENESIS_ENABLE_P60B_TRITON_KERNEL=1 \
        -e GENESIS_ENABLE_P60_GDN_NGRAM_FIX=1 \
        -e GENESIS_ENABLE_P61B_STREAMING_OVERLAP=1 \
        -e GENESIS_ENABLE_P61_QWEN3_MULTI_TOOL=1 \
        -e GENESIS_ENABLE_P62_STRUCT_OUT_SPEC_TIMING=1 \
        -e GENESIS_ENABLE_P64_QWEN3CODER_MTP_STREAMING=1 \
        -e GENESIS_ENABLE_P66_CUDAGRAPH_SIZE_FILTER=1 \
        -e GENESIS_ENABLE_P67_TQ_MULTI_QUERY_KERNEL=1 \
        -e GENESIS_ENABLE_P68_AUTO_FORCE_TOOL=1 \
        -e GENESIS_ENABLE_P69_LONG_CTX_TOOL_REMINDER=1 \
        -e GENESIS_ENABLE_P72_PROFILE_RUN_CAP=1 \
        -e GENESIS_ENABLE_P74_CHUNK_CLAMP=1 \
        -e GENESIS_ENABLE_P78_TOLIST_CAPTURE_GUARD=0 \
        -e GENESIS_ENABLE_P81_FP8_BLOCK_SCALED_M_LE_8=0 \
        -e GENESIS_ENABLE_P82=0 \
        -e GENESIS_ENABLE_P83=1 \
        -e GENESIS_ENABLE_P87=1 \
        -e GENESIS_ENABLE_P91=1 \
        -e GENESIS_ENABLE_P94=1 \
        -e GENESIS_ENABLE_P98=1 \
        -e GENESIS_ENABLE_P99=1 \
        -e GENESIS_ENABLE_PN11_GDN_AB_CONTIGUOUS=1 \
        -e GENESIS_ENABLE_PN12_FFN_INTERMEDIATE_POOL=1 \
        -e GENESIS_ENABLE_PN13_CUDA_GRAPH_LAMBDA_ARITY=1 \
        -e GENESIS_ENABLE_PN14_TQ_DECODE_OOB_CLAMP=1 \
        -e GENESIS_ENABLE_PN17_FA2_LSE_CLAMP=1 \
        -e GENESIS_ENABLE_PN19_SCOPED_MAX_SPLIT=1 \
        -e GENESIS_ENABLE_PN22_LOCAL_ARGMAX_TP=1 \
        -e GENESIS_ENABLE_PN25_SILU_INDUCTOR_SAFE=1 \
        -e GENESIS_ENABLE_PN26_SPARSE_V=1 \
        -e GENESIS_ENABLE_PN30_DS_LAYOUT_SPEC_DECODE=1 \
        -e GENESIS_ENABLE_PN34_WORKSPACE_LOCK_RELAX=1 \
        -e GENESIS_ENABLE_PN59_STREAMING_GDN=1 \
        -e GENESIS_ENABLE_PN8_MTP_DRAFT_ONLINE_QUANT=1 \
        -e GENESIS_ENABLE_PN9_INDEPENDENT_DRAFTER_ATTN=1 \
        -e GENESIS_P68_P69_LONG_CTX_THRESHOLD_CHARS=50000 \
        -e GENESIS_P82_THRESHOLD_SINGLE=0.3 \
        -e GENESIS_PN26_SPARSE_V_BLOCK_KV=8 \
        -e GENESIS_PN26_SPARSE_V_NUM_WARPS=4 \
        -e GENESIS_PN26_SPARSE_V_THRESHOLD=0.01 \
        -e GENESIS_PREALLOC_TOKEN_BUDGET=4128 \
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
        -e VLLM_SSM_CONV_STATE_LAYOUT=DS \
        -e VLLM_USE_FLASHINFER_SAMPLER=1 \
        -e VLLM_USE_FUSED_MOE_GROUPED_TOPK=1 \
        -e VLLM_WORKER_MULTIPROC_METHOD=spawn \
        -e VLLM_ENFORCE_EAGER \
        -v /mnt/ssd/vLLM/Models:/root/.cache/huggingface \
        -v /mnt/ssd/vLLM/Patches/genesis/vllm/_genesis:/usr/local/lib/python3.12/dist-packages/vllm/_genesis:ro \
        -v /mnt/ssd/vLLM/Patches/patch_timings_1acd67a.py:/patches/patch_timings_1acd67a.py:ro \
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
      "vision"
      "reasoning"
    ];
    reasoning = reasoning.qwen36Vllm;
  };
}
