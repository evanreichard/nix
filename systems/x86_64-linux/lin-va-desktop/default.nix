{ namespace
, pkgs
, lib
, ...
}:
let
  inherit (lib.${namespace}) enabled;

in
{
  system.stateVersion = "25.11";
  time.timeZone = "America/New_York";
  hardware.nvidia-container-toolkit.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    packageOverrides = pkgs: {
      llama-cpp =
        (pkgs.llama-cpp.override {
          cudaSupport = true;
          blasSupport = true;
          rocmSupport = false;
          metalSupport = false;
        }).overrideAttrs
          (oldAttrs: rec {
            version = "7213";
            src = pkgs.fetchFromGitHub {
              owner = "ggml-org";
              repo = "llama.cpp";
              tag = "b${version}";
              hash = "sha256-DVP1eGuSbKd0KxmrDCVAdOe16r1wJ9+RonbrUTgVS7U=";
              leaveDotGit = true;
              postFetch = ''
                git -C "$out" rev-parse --short HEAD > $out/COMMIT
                find "$out" -name .git -print0 | xargs -0 rm -rf
              '';
            };
            # Auto CPU Optimizations
            cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
              "-DGGML_NATIVE=ON"
              "-DGGML_CUDA_ENABLE_UNIFIED_MEMORY=1"
              "-DCMAKE_CUDA_ARCHITECTURES=61" # GTX 1070 / GTX 1080ti
            ];
            # Disable Nix's march=native Stripping
            preConfigure = ''
              export NIX_ENFORCE_NO_NATIVE=0
              ${oldAttrs.preConfigure or ""}
            '';
          });
    };
  };

  fileSystems."/mnt/ssd" = {
    device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_1TB_S6PTNZ0R620739L-part1";
    fsType = "exfat";
    options = [
      "uid=1000"
      "gid=100"
      "umask=0022"
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [ 8081 ];
  };

  # System Config
  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        silentBoot = true;
        enableSystemd = true;
        enableGrub = false;
      };
      disk = {
        enable = true;
        diskPath = "/dev/sdc";
      };
      networking = {
        enable = true;
        useStatic = {
          interface = "enp3s0";
          address = "10.0.20.100";
          defaultGateway = "10.0.20.254";
          nameservers = [ "10.0.20.20" ];
        };
      };
    };

    hardware = {
      opengl = {
        enable = true;
        enableNvidia = true;
      };
    };

    services = {
      openssh = enabled;
    };

    virtualisation = {
      # podman run --device nvidia.com/gpu=all -e INVOKEAI_ROOT=/invokeai -v /mnt/ssd/InvokeAI:/invokeai --publish 8081:9090 ghcr.io/invoke-ai/invokeai
      podman = enabled;
    };

  };

  services.llama-swap = {
    enable = true;
    openFirewall = true;
    settings = {
      models = {
        # https://huggingface.co/ggml-org/gpt-oss-20b-GGUF/tree/main
        # https://huggingface.co/mradermacher/gpt-oss-20b-heretic-GGUF/tree/main
        # reasoning_effort = low, medium, high
        "gpt-oss-20b-thinking" = {
          name = "GPT OSS (20B) - Thinking";
          cmd = "${pkgs.llama-cpp}/bin/llama-server --port \${PORT} -m /mnt/ssd/Models/gpt-oss-20b-heretic-MXFP4.gguf --ctx-size 128000 --chat-template-kwargs '{\"reasoning_effort\":\"low\"}'";
        };

        # https://huggingface.co/ggml-org/Qwen2.5-Coder-7B-Q8_0-GGUF/tree/main
        "qwen2.5-coder-7b-instruct" = {
          name = "Qwen2.5 Coder (7B) - Instruct";
          cmd = "${pkgs.llama-cpp}/bin/llama-server -m /mnt/ssd/Models/qwen2.5-coder-7b-q8_0.gguf --fim-qwen-7b-default --port \${PORT}";
        };

        # https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/tree/main
        "qwen3-coder-30b-instruct" = {
          name = "Qwen3 Coder (30B) - Instruct";
          cmd = "${pkgs.llama-cpp}/bin/llama-server --port \${PORT} -m /mnt/ssd/Models/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf --ctx-size 16384 --temp 0.7 --min-p 0.0 --top-p 0.8 --top-k 20 --cache-type-k q4_0 --cache-type-v q4_0";
        };

        # https://huggingface.co/unsloth/Qwen3-30B-A3B-Instruct-2507-GGUF/tree/main
        "qwen3-30b-instruct" = {
          name = "Qwen3 (30B) - Instruct";
          cmd = "${pkgs.llama-cpp}/bin/llama-server --port \${PORT} -m /mnt/ssd/Models/Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf --ctx-size 16384 --temp 0.7 --min-p 0.0 --top-p 0.8 --top-k 20 --cache-type-k q4_0 --cache-type-v q4_0";
        };

        # https://huggingface.co/unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF/tree/main
        "qwen3-30b-thinking" = {
          name = "Qwen3 (30B) - Thinking";
          cmd = "${pkgs.llama-cpp}/bin/llama-server --port \${PORT} -m /mnt/ssd/Models/Qwen3-30B-A3B-Thinking-2507-Q4_K_M.gguf --ctx-size 16384 --temp 0.7 --min-p 0.0 --top-p 0.8 --top-k 20 --cache-type-k q4_0 --cache-type-v q4_0";
        };

        # https://huggingface.co/unsloth/Qwen3-VL-8B-Instruct-GGUF/tree/main
        "qwen3-8b-vision" = {
          name = "Qwen3 Vision (8B) - Thinking";
          cmd = "${pkgs.llama-cpp}/bin/llama-server --port \${PORT} -m /mnt/ssd/Models/Qwen3-VL-8B-Instruct-UD-Q4_K_XL.gguf --mmproj /mnt/ssd/Models/Qwen3-VL-8B-Instruct-UD-Q4_K_XL_mmproj-F16.gguf --ctx-size 131072 --temp 0.7 --min-p 0.0 --top-p 0.8 --top-k 20  --cache-type-k q4_0 --cache-type-v q4_0";
        };
      };
    };
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    btop
    git
    tmux
    vim
    llama-cpp
  ];
}
