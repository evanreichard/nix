{ pkgs }:
let
  llama-cpp = pkgs.reichard.llama-cpp;
  ik-llama-cpp = pkgs.reichard.ik-llama-cpp;
  stable-diffusion-cpp = pkgs.reichard.stable-diffusion-cpp.override {
    cudaSupport = true;
  };
in
{
  healthCheckTimeout = 500;
  models = {
    # ---------------------------------------
    # -------------- RTX 3090 ---------------
    # ---------------------------------------

    # https://huggingface.co/mradermacher/gpt-oss-20b-heretic-v2-i1-GGUF/tree/main
    "gpt-oss-20b-cuda0" = {
      name = "GPT OSS 20B (CUDA0)";
      macros.ctx = "131072";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/GPT-OSS/gpt-oss-20b-heretic-v2.i1-MXFP4_MOE.gguf \
          -c ''${ctx} \
          --temp 1.0 \
          --top-p 1.0 \
          --top-k 40 \
          -dev CUDA0
      '';
      metadata = {
        type = [ "text-generation" ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/tree/main
    "qwen3.6-35b-cuda0" = {
      name = "Qwen3.6 35B (CUDA0, UD-Q4)";
      macros.ctx = "100000";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf \
          -c ''${ctx} \
          -np 2 -kvu \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.0 \
          --presence-penalty 0.0 \
          -ctk q8_0 \
          -ctv q8_0 \
          --spec-type draft-mtp \
          --spec-draft-n-max 3 \
          -dev CUDA0 \
          -fit off \
          --chat-template-kwargs "{\"preserve_thinking\": true}"
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3.6-27B-GGUF-MTP/tree/main
    "qwen3.6-27b-cuda0" = {
      name = "Qwen3.6 27B (CUDA0, UD-Q4)";
      macros.ctx = "140000";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-27B-UD-Q4_K_XL.gguf \
          -c ''${ctx} \
          -np 2 -kvu \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.00 \
          --presence-penalty 0.0 \
          -ctk q8_0 \
          -ctv q8_0 \
          --spec-type draft-mtp \
          --spec-draft-n-max 3 \
          -dev CUDA0 \
          -fit off \
          --chat-template-kwargs "{\"preserve_thinking\": true}"
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/gemma-4-26B-A4B-it-GGUF/tree/main
    "gemma-4-26b-vl-cuda0" = {
      name = "Gemma 4 26B (VL, CUDA0)";
      macros.ctx = "196608";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
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
        type = [
          "text-generation"
          "vision"
        ];
      };
    };

    # https://huggingface.co/Lorbus/Qwen3.6-27B-int4-AutoRound
    "qwen3.6-27b-vllm-50k-cuda0" = {
      name = "Qwen3.6 27B (vLLM, 50K, CUDA0)";
      checkEndpoint = "/v1/models";
      macros.ctx = "50000";
      proxy = "http://127.0.0.1:\${PORT}";
      cmd = ''
        ${pkgs.docker}/bin/docker run --rm --device=nvidia.com/gpu=all \
          --name ''${MODEL_ID} \
          -e CUDA_DEVICE_ORDER=PCI_BUS_ID \
          -e CUDA_VISIBLE_DEVICES=0 \
          -e VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=0 \
          -v /mnt/ssd/vLLM/Models:/root/.cache/huggingface \
          -p ''${PORT}:8000 \
          vllm/vllm-openai:latest \
          /root/.cache/huggingface/qwen3.6-27b-autoround-int4 \
          --served-model-name ''${MODEL_ID} \
          --quantization auto_round \
          --dtype float16 \
          --tensor-parallel-size 1 \
          --gpu-memory-utilization 0.97 \
          --max-model-len ''${ctx} \
          --max-num-seqs 1 \
          --max-num-batched-tokens 4128 \
          --kv-cache-dtype fp8_e5m2 \
          --enable-chunked-prefill \
          --enable-prefix-caching \
          --speculative-config '{"method":"mtp","num_speculative_tokens":3}' \
          --enable-auto-tool-choice \
          --tool-call-parser qwen3_coder \
          --trust-remote-code \
          --default-chat-template-kwargs '{"enable_thinking": false}' \
          --host 0.0.0.0 \
          --port 8000
      '';
      cmdStop = "${pkgs.docker}/bin/docker stop \${MODEL_ID}";
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://github.com/noonghunna/club-3090/tree/master/models/qwen3.6-27b/vllm
    "qwen3.6-27b-vllm-75k-cuda0" = {
      name = "Qwen3.6 27B (vLLM, 75K, CUDA0)";
      checkEndpoint = "/v1/models";
      macros.ctx = "75000";
      proxy = "http://127.0.0.1:\${PORT}";
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
          ${pkgs.docker}/bin/docker run --rm --device=nvidia.com/gpu=all \
            --name ''${MODEL_ID} \
            --ipc=host \
            -e CUDA_DEVICE_MAX_CONNECTIONS=8 \
            -e CUDA_DEVICE_ORDER=PCI_BUS_ID \
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

      cmdStop = "${pkgs.docker}/bin/docker stop \${MODEL_ID}";

      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://github.com/noonghunna/club-3090/tree/master/models/qwen3.6-27b/vllm
    "qwen3.6-27b-vllm-145k-vl-cuda0" = {
      name = "Qwen3.6 27B (vLLM, 145K, VL, CUDA0)";
      checkEndpoint = "/v1/models";
      macros.ctx = "145000";
      proxy = "http://127.0.0.1:\${PORT}";
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
          ${pkgs.docker}/bin/docker run --rm --device=nvidia.com/gpu=all \
            --name ''${MODEL_ID} \
            --ipc=host \
            -e CUDA_DEVICE_MAX_CONNECTIONS=8 \
            -e CUDA_DEVICE_ORDER=PCI_BUS_ID \
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

      cmdStop = "${pkgs.docker}/bin/docker stop \${MODEL_ID}";

      metadata = {
        type = [
          "text-generation"
          "coding"
          "vision"
        ];
      };
    };

    # https://github.com/noonghunna/club-3090/tree/master/models/qwen3.6-27b/vllm
    "qwen3.6-27b-vllm-180k-cuda0" = {
      name = "Qwen3.6 27B (vLLM, 180K, CUDA0)";
      checkEndpoint = "/v1/models";
      macros.ctx = "180000";
      proxy = "http://127.0.0.1:\${PORT}";
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
            --gpu-memory-utilization 0.93
            --max-num-seqs 1
            --max-num-batched-tokens 4128
            --kv-cache-dtype turboquant_3bit_nc
            --language-model-only
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
          ${pkgs.docker}/bin/docker run --rm --device=nvidia.com/gpu=all \
            --name ''${MODEL_ID} \
            --ipc=host \
            -e CUDA_DEVICE_MAX_CONNECTIONS=8 \
            -e CUDA_DEVICE_ORDER=PCI_BUS_ID \
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
            -e GENESIS_ENABLE_PN31_FA_VARLEN_PERSISTENT_OUT=1 \
            -e GENESIS_ENABLE_PN32_GDN_CHUNKED_PREFILL=1 \
            -e GENESIS_ENABLE_PN34_WORKSPACE_LOCK_RELAX=1 \
            -e GENESIS_ENABLE_PN59_STREAMING_GDN=1 \
            -e GENESIS_ENABLE_PN8_MTP_DRAFT_ONLINE_QUANT=1 \
            -e GENESIS_ENABLE_PN9_INDEPENDENT_DRAFTER_ATTN=1 \
            -e GENESIS_FLA_FWD_H_MAX_T=16384 \
            -e GENESIS_P68_P69_LONG_CTX_THRESHOLD_CHARS=50000 \
            -e GENESIS_P82_THRESHOLD_SINGLE=0.3 \
            -e GENESIS_PN26_SPARSE_V_BLOCK_KV=8 \
            -e GENESIS_PN26_SPARSE_V_NUM_WARPS=4 \
            -e GENESIS_PN26_SPARSE_V_THRESHOLD=0.01 \
            -e GENESIS_PN32_GDN_CHUNK_SIZE=8192 \
            -e GENESIS_PN32_GDN_CHUNK_THRESHOLD=16384 \
            -e GENESIS_PN59_DEBUG=1 \
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

      cmdStop = "${pkgs.docker}/bin/docker stop \${MODEL_ID}";

      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # ---------------------------------------
    # ------------- GTX 1080 Ti -------------
    # ---------------------------------------

    # https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/tree/main
    "qwen3.5-9b-vl-cuda1" = {
      name = "Qwen3.5 9B (VL, CUDA1)";
      macros.ctx = "131072";
      env = [ "CUDA_VISIBLE_DEVICES=1" ];
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.5/Qwen3.5-9B-IQ4_XS.gguf \
          --mmproj /mnt/ssd/Models/Qwen3.5/Qwen3.5-9B-IQ4_XS_mmproj-F16.gguf \
          -c ''${ctx} \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.0 \
          -fit off \
          -dev CUDA0
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
          "vision"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/tree/main
    "qwen3.5-4b-cuda1" = {
      name = "Qwen3.5 4B (CUDA1)";
      macros.ctx = "131072";
      env = [ "CUDA_VISIBLE_DEVICES=1" ];
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.5/Qwen3.5-4B-IQ4_XS.gguf \
          -c ''${ctx} \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.0 \
          -fit off \
          -dev CUDA0
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # ---------------------------------------
    # -------- RTX 3090 + GTX 1080 Ti -------
    # ---------------------------------------

    # https://huggingface.co/unsloth/Qwen3-Coder-Next-GGUF/tree/main
    "qwen3-coder-next-80b-dual" = {
      name = "Qwen3 Coder Next 80B (Dual GPU)";
      macros.ctx = "131072";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3/Qwen3-Coder-Next-UD-Q4_K_XL.gguf \
          -c ''${ctx} \
          --temp 1.0 \
          --top-p 0.95 \
          --min-p 0.01 \
          --top-k 40 \
          -fit off \
          -ncmoe 19 \
          -ts 78,22
      '';

      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3.6-27B-GGUF-MTP/tree/main
    "qwen3.6-27b-dual" = {
      name = "Qwen3.6 27B (Dual GPU, UD-Q6)";
      macros.ctx = "196608";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-27B-UD-Q6_K_XL.gguf \
          -c ''${ctx} \
          -np 4 -kvu \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.00 \
          --presence-penalty 0.0 \
          -ctk q8_0 \
          -ctv q8_0 \
          --spec-type draft-mtp \
          --spec-draft-n-max 3 \
          -dev CUDA0,CUDA1 \
          -ts 73,27 \
          -fit off \
          --chat-template-kwargs "{\"preserve_thinking\": true}"
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3.6-35B-A3B-MTP-GGUF/tree/main
    "qwen3.6-35b-dual" = {
      name = "Qwen3.6 35B (Dual GPU, UD-Q6)";
      macros.ctx = "262144";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-35B-A3B-UD-Q6_K.gguf \
          -c ''${ctx} \
          -np 4 -kvu \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.00 \
          --presence-penalty 0.0 \
          -ctk q8_0 \
          -ctv q8_0 \
          --spec-type draft-mtp \
          --spec-draft-n-max 3 \
          -dev CUDA0,CUDA1 \
          -fit off \
          -ts 7,3 \
          --chat-template-kwargs "{\"preserve_thinking\": true}"
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # ---------------------------------------
    # ---------- Stable Diffusion ----------
    # ---------------------------------------

    "z-image-turbo-cuda0" = {
      name = "Z-Image-Turbo";
      checkEndpoint = "/";
      env = [ "CUDA_VISIBLE_DEVICES=0" ];
      cmd = ''
        ${stable-diffusion-cpp}/bin/sd-server \
          --listen-port ''${PORT} \
          --diffusion-fa \
          --diffusion-model /mnt/ssd/StableDiffusion/ZImageTurbo/z-image-turbo-Q8_0.gguf \
          --vae /mnt/ssd/StableDiffusion/ZImageTurbo/ae.safetensors \
          --llm /mnt/ssd/Models/Qwen3/Qwen3-4B-Instruct-2507-Q4_K_M.gguf \
          --cfg-scale 1.0 \
          --steps 8 \
          --rng cuda
      '';
      metadata = {
        type = [ "image-generation" ];
      };
    };

    "qwen-image-edit-2511-cuda0" = {
      name = "Qwen Image Edit 2511";
      checkEndpoint = "/";
      env = [ "CUDA_VISIBLE_DEVICES=0" ];
      cmd = ''
        ${stable-diffusion-cpp}/bin/sd-server \
          --listen-port ''${PORT} \
          --diffusion-fa \
          --qwen-image-zero-cond-t \
          --diffusion-model /mnt/ssd/StableDiffusion/QwenImage/qwen-image-edit-2511-Q5_K_M.gguf \
          --vae /mnt/ssd/StableDiffusion/QwenImage/qwen_image_vae.safetensors \
          --llm /mnt/ssd/Models/Qwen2.5/Qwen2.5-VL-7B-Instruct.Q4_K_M.gguf \
          --lora-model-dir /mnt/ssd/StableDiffusion/QwenImage/Loras \
          --cfg-scale 2.5 \
          --sampling-method euler \
          --flow-shift 3 \
          --steps 20 \
          --rng cuda
      '';
      metadata = {
        type = [
          "image-edit"
          "image-generation"
        ];
      };
    };

    "qwen-image-2512-cuda0" = {
      name = "Qwen Image 2512";
      checkEndpoint = "/";
      env = [ "CUDA_VISIBLE_DEVICES=0" ];
      cmd = ''
        ${stable-diffusion-cpp}/bin/sd-server \
          --listen-port ''${PORT} \
          --diffusion-fa \
          --diffusion-model /mnt/ssd/StableDiffusion/QwenImage/qwen-image-2512-Q5_K_M.gguf \
          --vae /mnt/ssd/StableDiffusion/QwenImage/qwen_image_vae.safetensors \
          --llm /mnt/ssd/Models/Qwen2.5/Qwen2.5-VL-7B-Instruct.Q4_K_M.gguf \
          --lora-model-dir /mnt/ssd/StableDiffusion/QwenImage/Loras \
          --cfg-scale 2.5 \
          --sampling-method euler \
          --flow-shift 3 \
          --steps 20 \
          --rng cuda
      '';
      metadata = {
        type = [ "image-generation" ];
      };
    };

    "chroma-radiance-cuda0" = {
      name = "Chroma Radiance";
      checkEndpoint = "/";
      env = [ "CUDA_VISIBLE_DEVICES=0" ];
      cmd = ''
        ${stable-diffusion-cpp}/bin/sd-server \
          --listen-port ''${PORT} \
          --diffusion-fa --chroma-disable-dit-mask \
          --diffusion-model /mnt/ssd/StableDiffusion/Chroma/chroma_radiance_x0_q8.gguf \
          --t5xxl /mnt/ssd/StableDiffusion/Chroma/t5xxl_fp16.safetensors \
          --cfg-scale 4.0 \
          --sampling-method euler \
          --rng cuda
      '';
      metadata = {
        type = [ "image-generation" ];
      };
    };
  };

  # Concurrent Model Matrix
  #
  # CUDA0 models can run alongside CUDA1 models (one each). Models not
  # listed in any set (dual-GPU models) run alone and evict everything.
  matrix = {
    vars = {
      # --- RTX 3090 Models ---
      v180 = "qwen3.6-27b-vllm-180k-cuda0";
      v145 = "qwen3.6-27b-vllm-145k-vl-cuda0";
      v75 = "qwen3.6-27b-vllm-75k-cuda0";
      v50 = "qwen3.6-27b-vllm-50k-cuda0";
      go = "gpt-oss-20b-cuda0";
      g4 = "gemma-4-26b-vl-cuda0";
      q36a = "qwen3.6-35b-cuda0";
      q36b = "qwen3.6-27b-cuda0";
      zi = "z-image-turbo-cuda0";
      qie = "qwen-image-edit-2511-cuda0";
      qi = "qwen-image-2512-cuda0";
      cr = "chroma-radiance-cuda0";

      # --- GTX 1080 Ti Models ---
      q4 = "qwen3.5-4b-cuda1";
      q9 = "qwen3.5-9b-vl-cuda1";
    };

    sets = {
      concurrent = "(go | g4 | q36a | q36b | v180 | v145 | v75 | v50 | zi | qie | qi | cr) & (q4 | q9)";
    };
  };
}
