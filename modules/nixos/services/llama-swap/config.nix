{ pkgs }:
let
  llama-cpp = pkgs.reichard.llama-cpp;
  stable-diffusion-cpp = pkgs.reichard.stable-diffusion-cpp.override {
    cudaSupport = true;
  };
in
{
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

    # https://huggingface.co/mradermacher/GPT-OSS-Cybersecurity-20B-Merged-i1-GGUF/tree/main
    "gpt-oss-csec-20b-thinking" = {
      name = "GPT OSS CSEC (20B) - Thinking";
      macros.ctx = "131072";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/GPT-OSS/GPT-OSS-Cybersecurity-20B-Merged.i1-MXFP4_MOE.gguf \
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

    # https://huggingface.co/unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF/tree/main
    "qwen3-next-80b-instruct" = {
      name = "Qwen3 Next (80B) - Instruct";
      macros.ctx = "262144";
      cmd = ''
        ${llama-cpp}/bin/llama-server \
          --port ''${PORT} \
          -m /mnt/ssd/Models/Qwen3/Qwen3-Next-80B-A3B-Instruct-UD-Q2_K_XL.gguf \
          -c ''${ctx} \
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
        type = [
          "text-generation"
          "coding"
        ];
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
          -ncmoe 18 \
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
      # --chat-template-kwargs "{\"enable_thinking\": false}"
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
        type = [ "text-generation" ];
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

  peers = {
    synthetic = {
      proxy = "https://api.synthetic.new/openai/";
      models = [
        "hf:MiniMaxAI/MiniMax-M2.1"
        "hf:MiniMaxAI/MiniMax-M2.5"
        "hf:moonshotai/Kimi-K2.5"
        "hf:moonshotai/Kimi-K2-Instruct-0905"
        "hf:moonshotai/Kimi-K2-Thinking"
        "hf:openai/gpt-oss-120b"
        "hf:Qwen/Qwen3.5-397B-A17B"
        "hf:zai-org/GLM-4.7"
      ];
    };
  };
}
