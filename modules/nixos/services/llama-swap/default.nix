{ config
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.${namespace}.services.llama-swap;

  llama-swap = pkgs.reichard.llama-swap;
  llama-cpp = pkgs.reichard.llama-cpp;
  stable-diffusion-cpp = pkgs.reichard.stable-diffusion-cpp.override {
    cudaSupport = true;
  };
in
{
  options.${namespace}.services.llama-swap = {
    enable = mkEnableOption "enable llama-swap service";
  };

  config = mkIf cfg.enable {
    # Create User
    users.groups.llama-swap = { };
    users.users.llama-swap = {
      isSystemUser = true;
      group = "llama-swap";
    };

    # Create Service
    systemd.services.llama-swap = {
      description = "Model swapping for LLaMA C++ Server (or any local OpenAPI compatible server)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "exec";
        ExecStart = "${lib.getExe llama-swap} --listen :8080 --config ${
          config.sops.templates."llama-swap.json".path
        }";
        Restart = "on-failure";
        RestartSec = 3;

        # for GPU acceleration
        PrivateDevices = false;

        # hardening
        User = "llama-swap";
        Group = "llama-swap";
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        NoNewPrivileges = true;
        PrivateMounts = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        MemoryDenyWriteExecute = true;
        LimitMEMLOCK = "infinity";
        LockPersonality = true;
        RemoveIPC = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        SystemCallErrorNumber = "EPERM";
        ProtectProc = "invisible";
        ProtectHostname = true;
        ProcSubset = "pid";
      };
    };

    # Create Config
    sops = {
      secrets.synthetic_apikey = {
        sopsFile = lib.snowfall.fs.get-file "secrets/common/systems.yaml";
      };
      templates."llama-swap.json" = {
        owner = "llama-swap";
        group = "llama-swap";
        mode = "0400";
        content = builtins.toJSON {
          models = {
            # https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF/tree/main
            "devstral-small-2-instruct" = {
              name = "Devstral Small 2 (24B) - Instruct";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/Devstral/Devstral-Small-2-24B-Instruct-2512-UD-Q4_K_XL.gguf \
                  --chat-template-file /mnt/ssd/Models/Devstral/Devstral-Small-2-24B-Instruct-2512-UD-Q4_K_XL_template.jinja \
                  --temp 0.15 \
                  -c 98304 \
                  -ctk q8_0 \
                  -ctv q8_0 \
                  -fit off \
                  -dev CUDA0
              '';
              metadata = {
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/mradermacher/gpt-oss-20b-heretic-v2-i1-GGUF/tree/main
            "gpt-oss-20b-thinking" = {
              name = "GPT OSS (20B) - Thinking";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/GPT-OSS/gpt-oss-20b-heretic-v2.i1-MXFP4_MOE.gguf \
                  -c 131072 \
                  --temp 1.0 \
                  --top-p 1.0 \
                  --top-k 40 \
                  -dev CUDA0
              '';
              metadata = {
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/mradermacher/GPT-OSS-Cybersecurity-20B-Merged-i1-GGUF/tree/main
            "gpt-oss-csec-20b-thinking" = {
              name = "GPT OSS CSEC (20B) - Thinking";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/GPT-OSS/GPT-OSS-Cybersecurity-20B-Merged.i1-MXFP4_MOE.gguf \
                  -c 131072 \
                  --temp 1.0 \
                  --top-p 1.0 \
                  --top-k 40 \
                  -dev CUDA0
              '';
              metadata = {
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF/tree/main
            "qwen3-next-80b-instruct" = {
              name = "Qwen3 Next (80B) - Instruct";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/Qwen3/Qwen3-Next-80B-A3B-Instruct-UD-Q2_K_XL.gguf \
                  -c 262144 \
                  --temp 0.7 \
                  --min-p 0.0 \
                  --top-p 0.8 \
                  --top-k 20 \
                  --repeat-penalty 1.05 \
                  -ctk q8_0 \
                  -ctv q8_0 \
                  -fit off
              '';
              metadata = {
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Qwen3-30B-A3B-Instruct-2507-GGUF/tree/main
            "qwen3-30b-2507-instruct" = {
              name = "Qwen3 2507 (30B) - Instruct";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/Qwen3/Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf \
                  -c 262144 \
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
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/tree/main
            "qwen3-coder-30b-instruct" = {
              name = "Qwen3 Coder (30B) - Instruct";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/Qwen3/Qwen3-Coder-30B-A3B-Instruct-UD-Q6_K_XL.gguf \
                  -c 131072 \
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
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF/tree/main
            "qwen3-30b-2507-thinking" = {
              name = "Qwen3 2507 (30B) - Thinking";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/Qwen3/Qwen3-30B-A3B-Thinking-2507-UD-Q4_K_XL.gguf \
                  -c 262144 \
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
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Nemotron-3-Nano-30B-A3B-GGUF/tree/main
            "nemotron-3-nano-30b-thinking" = {
              name = "Nemotron 3 Nano (30B) - Thinking";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/Nemotron/Nemotron-3-Nano-30B-A3B-UD-Q4_K_XL.gguf \
                  -c 1048576 \
                  --temp 1.1 \
                  --top-p 0.95 \
                  -fit off
              '';
              metadata = {
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Qwen3-VL-8B-Instruct-GGUF/tree/main
            "qwen3-8b-vision" = {
              name = "Qwen3 Vision (8B) - Thinking";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/Qwen3/Qwen3-VL-8B-Instruct-UD-Q4_K_XL.gguf \
                  --mmproj /mnt/ssd/Models/Qwen3/Qwen3-VL-8B-Instruct-UD-Q4_K_XL_mmproj-F16.gguf \
                  -c 65536 \
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
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF/tree/main
            "qwen2.5-coder-7b-instruct" = {
              name = "Qwen2.5 Coder (7B) - Instruct";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  -m /mnt/ssd/Models/Qwen2.5/Qwen2.5-Coder-7B-Instruct-Q8_0.gguf \
                  --fim-qwen-7b-default \
                  -c 131072 \
                  --port ''${PORT} \
                  -fit off \
                  -dev CUDA1
              '';
              metadata = {
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Qwen2.5-Coder-3B-Instruct-128K-GGUF/tree/main
            "qwen2.5-coder-3b-instruct" = {
              name = "Qwen2.5 Coder (3B) - Instruct";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  -m /mnt/ssd/Models/Qwen2.5/Qwen2.5-Coder-3B-Instruct-Q8_0.gguf \
                  --fim-qwen-3b-default \
                  --port ''${PORT} \
                  -fit off \
                  -dev CUDA1
              '';
              metadata = {
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/tree/main
            "qwen3-4b-2507-instruct" = {
              name = "Qwen3 2507 (4B) - Instruct";
              cmd = ''
                ${llama-cpp}/bin/llama-server \
                  --port ''${PORT} \
                  -m /mnt/ssd/Models/Qwen3/Qwen3-4B-Instruct-2507-Q4_K_M.gguf \
                  -c 98304 \
                  -fit off \
                  -ctk q8_0 \
                  -ctv q8_0 \
                  -dev CUDA1
              '';
              metadata = {
                type = [ "text-generation" ];
              };
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

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
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };

            # https://huggingface.co/unsloth/Qwen-Image-Edit-2511-GGUF/tree/main
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
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
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
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
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
              env = [ "GGML_CUDA_ENABLE_UNIFIED_MEMORY=1" ];
            };
          };

          groups = {
            shared = {
              swap = true;
              exclusive = false;
              members = [
                "nemotron-3-nano-30b-thinking"
                "qwen3-30b-2507-instruct"
                "qwen3-30b-2507-thinking"
                "qwen3-coder-30b-instruct"
                "qwen3-next-80b-instruct"
              ];
            };

            cuda0 = {
              swap = true;
              exclusive = false;
              members = [
                "devstral-small-2-instruct"
                "gpt-oss-20b-thinking"
                "gpt-oss-csec-20b-thinking"
              ];
            };

            cuda1 = {
              swap = true;
              exclusive = false;
              members = [
                "qwen2.5-coder-3b-instruct"
                "qwen2.5-coder-7b-instruct"
                "qwen3-4b-2507-instruct"
                "qwen3-8b-vision"
              ];
            };
          };

          peers = {
            synthetic = {
              proxy = "https://api.synthetic.new/openai/";
              apiKey = "${config.sops.placeholder.synthetic_apikey}";
              models = [
                "hf:deepseek-ai/DeepSeek-R1-0528"
                "hf:deepseek-ai/DeepSeek-V3"
                "hf:deepseek-ai/DeepSeek-V3-0324"
                "hf:deepseek-ai/DeepSeek-V3.1"
                "hf:deepseek-ai/DeepSeek-V3.1-Terminus"
                "hf:deepseek-ai/DeepSeek-V3.2"
                "hf:meta-llama/Llama-3.3-70B-Instruct"
                "hf:meta-llama/Llama-4-Maverick-17B-128E-Instruct-FP8"
                "hf:MiniMaxAI/MiniMax-M2"
                "hf:MiniMaxAI/MiniMax-M2.1"
                "hf:moonshotai/Kimi-K2-Instruct-0905"
                "hf:moonshotai/Kimi-K2-Thinking"
                "hf:openai/gpt-oss-120b"
                "hf:Qwen/Qwen3-235B-A22B-Instruct-2507"
                "hf:Qwen/Qwen3-235B-A22B-Thinking-2507"
                "hf:Qwen/Qwen3-Coder-480B-A35B-Instruct"
                "hf:Qwen/Qwen3-VL-235B-A22B-Instruct"
                "hf:zai-org/GLM-4.5"
                "hf:zai-org/GLM-4.6"
                "hf:zai-org/GLM-4.7"
              ];
            };
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ 8080 ];
  };
}
