{ pkgs }:
let
  llama-cpp = pkgs.reichard.llama-cpp;
  stable-diffusion-cpp = pkgs.reichard.stable-diffusion-cpp.override {
    cudaSupport = true;
  };
in
{
  healthCheckTimeout = 500;
  models = {
    # https://huggingface.co/unsloth/GLM-4.7-Flash-GGUF/tree/main
    "glm-4.7-flash" = {
      name = "GLM 4.7 Flash (30B) - Thinking";
      macros.ctx = "131072";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/GLM/GLM-4.7-Flash-UD-Q6_K_XL.gguf \
          -c ''${ctx} \
          --temp 0.7 \
          --top-p 1.0 \
          --min-p 0.01 \
          --repeat-penalty 1.0 \
          -fit off \
          -ts 70,30
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF/tree/main
    "devstral-small-2-instruct" = {
      name = "Devstral Small 2 (24B) - Instruct";
      macros.ctx = "131072";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Devstral/Devstral-Small-2-24B-Instruct-2512-UD-Q6_K_XL.gguf \
          --temp 0.15 \
          -c ''${ctx} \
          -ctk q8_0 \
          -ctv q8_0 \
          -fit off \
          -ts 75,25
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/mradermacher/gpt-oss-20b-heretic-v2-i1-GGUF/tree/main
    "gpt-oss-20b-thinking" = {
      name = "GPT OSS (20B) - Thinking";
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

    # https://huggingface.co/unsloth/Qwen3-Coder-Next-GGUF/tree/main
    "qwen3-coder-next-80b-instruct" = {
      name = "Qwen3 Coder Next (80B) - Instruct";
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

    # https://huggingface.co/AesSedai/Qwen3.5-35B-A3B-GGUF/tree/main
    "qwen3.5-35b-thinking" = {
      name = "Qwen3.5 (35B) - Thinking";
      macros.ctx = "262144";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.5/Qwen3.5-35B-A3B-IQ4_XS-00001-of-00002.gguf \
          -c ''${ctx} \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.00 \
          -dev CUDA0 \
          -fit off
      '';
      # --chat-template-kwargs "{\"enable_thinking\": false}"
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/tree/main
    "qwen3.6-35b-thinking" = {
      name = "Qwen3.6 (35B) - Thinking";
      macros.ctx = "262144";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf \
          -c ''${ctx} \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.0 \
          --presence-penalty 0.0 \
          --repeat-penalty 1.0 \
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

    # https://huggingface.co/bartowski/Qwen_Qwen3.5-27B-GGUF/tree/main
    "qwen3.5-27b-thinking" = {
      name = "Qwen3.5 (27B) - Thinking";
      macros.ctx = "196608";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.5/Qwen_Qwen3.5-27B-IQ4_XS.gguf \
          -c ''${ctx} \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.00 \
          -ctk q8_0 \
          -ctv q8_0 \
          -dev CUDA0 \
          -fit off
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3.6-27B-GGUF/tree/main
    "qwen3.6-27b-thinking" = {
      name = "Qwen3.6 (27B) - Thinking";
      macros.ctx = "196608";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3.6/Qwen3.6-27B-IQ4_XS.gguf \
          -c ''${ctx} \
          --parallel 2 \
          --temp 0.6 \
          --top-p 0.95 \
          --top-k 20 \
          --min-p 0.00 \
          --presence-penalty 1.5 \
          -ctk q8_0 \
          -ctv q8_0 \
          --keep 3000 \
          --batch-size 4096 \
          --ubatch-size 1024 \
          --spec-type ngram-mod \
          --spec-ngram-mod-n-match 24 \
          --spec-draft-n-min 16 \
          --spec-draft-n-max 64 \
          -dev CUDA0 \
          -fit off \
          --chat-template-kwargs "{\"preserve_thinking\": true}"
      '';
      # --chat-template-kwargs "{\"enable_thinking\": false}"
      # --spec-draft-n-min 16 \
      # --spec-draft-n-max 32 \
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3-30B-A3B-Instruct-2507-GGUF/tree/main
    "qwen3-30b-2507-instruct" = {
      name = "Qwen3 2507 (30B) - Instruct";
      macros.ctx = "262144";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3/Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf \
          -c ''${ctx} \
          --temp 0.7 \
          --min-p 0.0 \
          --top-p 0.8 \
          --top-k 20 \
          --presence-penalty 1.0 \
          --repeat-penalty 1.0 \
          -ctk q8_0 \
          -ctv q8_0 \
          -ts 70,30 \
          -fit off
      '';
      metadata = {
        type = [ "text-generation" ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/tree/main
    "qwen3-coder-30b-instruct" = {
      name = "Qwen3 Coder (30B) - Instruct";
      macros.ctx = "131072";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3/Qwen3-Coder-30B-A3B-Instruct-UD-Q6_K_XL.gguf \
          -c ''${ctx} \
          --temp 0.7 \
          --min-p 0.0 \
          --top-p 0.8 \
          --top-k 20 \
          --repeat-penalty 1.05 \
          -ctk q8_0 \
          -ctv q8_0 \
          -ts 70,30 \
          -fit off
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF/tree/main
    "qwen3-30b-2507-thinking" = {
      name = "Qwen3 2507 (30B) - Thinking";
      macros.ctx = "262144";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3/Qwen3-30B-A3B-Thinking-2507-UD-Q4_K_XL.gguf \
          -c ''${ctx} \
          --temp 0.6 \
          --min-p 0.0 \
          --top-p 0.95 \
          --top-k 20 \
          --presence-penalty 1.0 \
          --repeat-penalty 1.0 \
          -ctk q8_0 \
          -ctv q8_0 \
          -ts 70,30 \
          -fit off
      '';
      metadata = {
        type = [ "text-generation" ];
      };
    };

    # https://huggingface.co/unsloth/Nemotron-3-Nano-30B-A3B-GGUF/tree/main
    "nemotron-3-nano-30b-thinking" = {
      name = "Nemotron 3 Nano (30B) - Thinking";
      macros.ctx = "1048576";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Nemotron/Nemotron-3-Nano-30B-A3B-UD-Q4_K_XL.gguf \
          -c ''${ctx} \
          --temp 1.1 \
          --top-p 0.95 \
          -fit off
      '';
      metadata = {
        type = [
          "text-generation"
          "coding"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3-VL-8B-Instruct-GGUF/tree/main
    "qwen3-8b-vision" = {
      name = "Qwen3 Vision (8B) - Thinking";
      macros.ctx = "65536";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3/Qwen3-VL-8B-Instruct-UD-Q4_K_XL.gguf \
          --mmproj /mnt/ssd/Models/Qwen3/Qwen3-VL-8B-Instruct-UD-Q4_K_XL_mmproj-F16.gguf \
          -c ''${ctx} \
          --temp 0.7 \
          --min-p 0.0 \
          --top-p 0.8 \
          --top-k 20 \
          -ctk q8_0 \
          -ctv q8_0 \
          -fit off \
          -dev CUDA1
      '';
      metadata = {
        type = [
          "text-generation"
          "vision"
        ];
      };
    };

    # https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/tree/main
    "qwen3-4b-2507-instruct" = {
      name = "Qwen3 2507 (4B) - Instruct";
      macros.ctx = "98304";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3/Qwen3-4B-Instruct-2507-Q4_K_M.gguf \
          -c ''${ctx} \
          -fit off \
          -ctk q8_0 \
          -ctv q8_0 \
          -dev CUDA1
      '';
      metadata = {
        type = [ "text-generation" ];
      };
    };

    # https://github.com/noonghunna/club-3090/tree/v0.20-experimental/models/qwen3.6-27b/vllm
    # Long-text variant - v0.20 experimental single-3090 profile, text-only (no vision)
    # TurboQuant 3-bit KV + MTP n=3 + workspace-lock sidecar.
    "vllm-qwen3.6-27b-long-text" = {
      name = "vLLM Qwen3.6 (27B) - Long Text";
      macros.ctx = "214000";
      proxy = "http://127.0.0.1:\${PORT}";
      cmd =
        let
          vllmCmd = ''
            set -e; pip install xxhash pandas scipy -q;
            python3 -m vllm._genesis.patches.apply_all;
            python3 /patches/patch_pn12_compile_safe_custom_op.py;
            python3 /patches/patch_workspace_lock_disable.py;
            python3 /patches/patch_tolist_cudagraph.py;
            python3 /patches/patch_timings_07351e088.py;
            exec vllm serve
            --served-model-name ''${MODEL_ID}
            --model /root/.cache/huggingface/qwen3.6-27b-autoround-int4
            --quantization auto_round
            --dtype float16
            --tensor-parallel-size 1
            --max-model-len ''${ctx}
            --gpu-memory-utilization 0.985
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
            -e VLLM_WORKER_MULTIPROC_METHOD=spawn \
            -e NCCL_CUMEM_ENABLE=0 \
            -e NCCL_P2P_DISABLE=1 \
            -e VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=0 \
            -e VLLM_NO_USAGE_STATS=1 \
            -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:512 \
            -e VLLM_FLOAT32_MATMUL_PRECISION=high \
            -e VLLM_USE_FLASHINFER_SAMPLER=1 \
            -e OMP_NUM_THREADS=1 \
            -e CUDA_DEVICE_MAX_CONNECTIONS=8 \
            -e CUDA_VISIBLE_DEVICES=0 \
            -e CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -e VLLM_ALLOW_LONG_MAX_MODEL_LEN=1 \
            -e VLLM_MARLIN_USE_ATOMIC_ADD=1 \
            -e GENESIS_ENABLE_P65_TURBOQUANT_SPEC_CG_DOWNGRADE=1 \
            -e GENESIS_ENABLE_P66_CUDAGRAPH_SIZE_FILTER=1 \
            -e GENESIS_ENABLE_P64_QWEN3CODER_MTP_STREAMING=1 \
            -e GENESIS_ENABLE_P101=1 \
            -e GENESIS_ENABLE_P103=1 \
            -e GENESIS_ENABLE_PN12_FFN_INTERMEDIATE_POOL=1 \
            -e GENESIS_ENABLE_PN13_CUDA_GRAPH_LAMBDA_ARITY=1 \
            -e GENESIS_ENABLE_PN17_FA2_LSE_CLAMP=1 \
            -e GENESIS_ENABLE_PN19_SCOPED_MAX_SPLIT=1 \
            -e GENESIS_ENABLE_P98=1 \
            -v /mnt/ssd/vLLM/Models:/root/.cache/huggingface \
            -v /mnt/ssd/vLLM/Patches/genesis/vllm/_genesis:/usr/local/lib/python3.12/dist-packages/vllm/_genesis:ro \
            -v /mnt/ssd/vLLM/Patches/patch_tolist_cudagraph.py:/patches/patch_tolist_cudagraph.py:ro \
            -v /mnt/ssd/vLLM/Patches/patch_pn12_compile_safe_custom_op.py:/patches/patch_pn12_compile_safe_custom_op.py:ro \
            -v /mnt/ssd/vLLM/Patches/patch_workspace_lock_disable.py:/patches/patch_workspace_lock_disable.py:ro \
            -v /mnt/ssd/vLLM/Patches/patch_timings_07351e088.py:/patches/patch_timings_07351e088.py:ro \
            -p ''${PORT}:8000 \
            --entrypoint /bin/bash \
            vllm/vllm-openai:nightly-7a1eb8ac2ec4ea69338c51dc7afd4b15010abfa8 \
            -c "${vllmCmdFlat}"
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
    # Tools-text variant - 75K context, text-only (no vision)
    # fp8_e5m2 KV + MTP n=3. This is the repo's validated long-context
    # tool-calling profile and should be more stable than TurboQuant 128K.
    "vllm-qwen3.6-27b-tools-text" = {
      name = "vLLM Qwen3.6 (27B) - Tools Text";
      macros.ctx = "75000";
      proxy = "http://127.0.0.1:\${PORT}";
      cmd =
        let
          vllmCmd = ''
            set -e; pip install xxhash pandas scipy -q;
            python3 -m vllm._genesis.patches.apply_all;
            python3 /patches/patch_tolist_cudagraph.py;
            python3 /patches/patch_timings_07351e088.py;
            exec vllm serve
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
            -e VLLM_WORKER_MULTIPROC_METHOD=spawn \
            -e NCCL_CUMEM_ENABLE=0 \
            -e NCCL_P2P_DISABLE=1 \
            -e VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=1 \
            -e VLLM_NO_USAGE_STATS=1 \
            -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:512 \
            -e VLLM_FLOAT32_MATMUL_PRECISION=high \
            -e VLLM_USE_FLASHINFER_SAMPLER=1 \
            -e OMP_NUM_THREADS=1 \
            -e CUDA_DEVICE_MAX_CONNECTIONS=8 \
            -e CUDA_VISIBLE_DEVICES=0 \
            -e CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -e VLLM_ALLOW_LONG_MAX_MODEL_LEN=1 \
            -e VLLM_MARLIN_USE_ATOMIC_ADD=1 \
            -e GENESIS_ENABLE_P64_QWEN3CODER_MTP_STREAMING=1 \
            -e GENESIS_ENABLE_PN8_MTP_DRAFT_ONLINE_QUANT=1 \
            -v /mnt/ssd/vLLM/Models:/root/.cache/huggingface \
            -v /mnt/ssd/vLLM/Patches/genesis/vllm/_genesis:/usr/local/lib/python3.12/dist-packages/vllm/_genesis:ro \
            -v /mnt/ssd/vLLM/Patches/patch_tolist_cudagraph.py:/patches/patch_tolist_cudagraph.py:ro \
            -v /mnt/ssd/vLLM/Patches/patch_timings_07351e088.py:/patches/patch_timings_07351e088.py:ro \
            -p ''${PORT}:8000 \
            --entrypoint /bin/bash \
            vllm/vllm-openai:nightly-07351e0883470724dd5a7e9730ed10e01fc99d08 \
            -c "${vllmCmdFlat}"
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
    # Long-vision variant - 140K context with vision tower active
    # TurboQuant 3-bit KV + MTP n=3 + PN12/P104 cliff-closure stack
    "vllm-qwen3.6-27b-long-vision" = {
      name = "vLLM Qwen3.6 (27B) - Long Vision";
      macros.ctx = "140000";
      proxy = "http://127.0.0.1:\${PORT}";
      cmd =
        let
          vllmCmd = ''
            set -e; pip install xxhash pandas scipy -q;
            python3 -m vllm._genesis.patches.apply_all;
            python3 /patches/patch_pn12_ffn_pool_anchor.py;
            python3 /patches/patch_pn12_compile_safe_custom_op.py;
            python3 /patches/patch_fa_max_seqlen_clamp.py;
            python3 /patches/patch_tolist_cudagraph.py;
            python3 /patches/patch_timings_07351e088.py;
            exec vllm serve
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
            -e VLLM_WORKER_MULTIPROC_METHOD=spawn \
            -e NCCL_CUMEM_ENABLE=0 \
            -e NCCL_P2P_DISABLE=1 \
            -e VLLM_MEMORY_PROFILER_ESTIMATE_CUDAGRAPHS=1 \
            -e VLLM_NO_USAGE_STATS=1 \
            -e PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True,max_split_size_mb:512 \
            -e VLLM_FLOAT32_MATMUL_PRECISION=high \
            -e VLLM_USE_FLASHINFER_SAMPLER=1 \
            -e OMP_NUM_THREADS=1 \
            -e CUDA_DEVICE_MAX_CONNECTIONS=8 \
            -e CUDA_VISIBLE_DEVICES=0 \
            -e CUDA_DEVICE_ORDER=PCI_BUS_ID \
            -e VLLM_ALLOW_LONG_MAX_MODEL_LEN=1 \
            -e VLLM_MARLIN_USE_ATOMIC_ADD=1 \
            -e GENESIS_ENABLE_P65_TURBOQUANT_SPEC_CG_DOWNGRADE=1 \
            -e GENESIS_ENABLE_P66_CUDAGRAPH_SIZE_FILTER=1 \
            -e GENESIS_ENABLE_P64_QWEN3CODER_MTP_STREAMING=1 \
            -e GENESIS_ENABLE_P101=1 \
            -e GENESIS_ENABLE_P103=1 \
            -e GENESIS_ENABLE_PN12_FFN_INTERMEDIATE_POOL=1 \
            -e GENESIS_ENABLE_PN13_CUDA_GRAPH_LAMBDA_ARITY=1 \
            -e GENESIS_ENABLE_FA_MAX_SEQLEN_CLAMP=1 \
            -e GENESIS_ENABLE_PN17_FA2_LSE_CLAMP=1 \
            -v /mnt/ssd/vLLM/Models:/root/.cache/huggingface \
            -v /mnt/ssd/vLLM/Patches/genesis/vllm/_genesis:/usr/local/lib/python3.12/dist-packages/vllm/_genesis:ro \
            -v /mnt/ssd/vLLM/Patches/patch_tolist_cudagraph.py:/patches/patch_tolist_cudagraph.py:ro \
            -v /mnt/ssd/vLLM/Patches/patch_pn12_ffn_pool_anchor.py:/patches/patch_pn12_ffn_pool_anchor.py:ro \
            -v /mnt/ssd/vLLM/Patches/patch_pn12_compile_safe_custom_op.py:/patches/patch_pn12_compile_safe_custom_op.py:ro \
            -v /mnt/ssd/vLLM/Patches/patch_fa_max_seqlen_clamp.py:/patches/patch_fa_max_seqlen_clamp.py:ro \
            -v /mnt/ssd/vLLM/Patches/patch_timings_07351e088.py:/patches/patch_timings_07351e088.py:ro \
            -p ''${PORT}:8000 \
            --entrypoint /bin/bash \
            vllm/vllm-openai:nightly-07351e0883470724dd5a7e9730ed10e01fc99d08 \
            -c "${vllmCmdFlat}"
        '';
      cmdStop = "${pkgs.docker}/bin/docker stop \${MODEL_ID}";

      metadata = {
        type = [
          "text-generation"
          "coding"
          "vision"
        ];
      };
    };

    # ---------------------------------------
    # ---------- Stable Diffussion ----------
    # ---------------------------------------

    "z-image-turbo" = {
      name = "Z-Image-Turbo";
      checkEndpoint = "/";
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

    "qwen-image-edit-2511" = {
      name = "Qwen Image Edit 2511";
      checkEndpoint = "/";
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

    "qwen-image-2512" = {
      name = "Qwen Image 2512";
      checkEndpoint = "/";
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

    "chroma-radiance" = {
      name = "Chroma Radiance";
      checkEndpoint = "/";
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
}
