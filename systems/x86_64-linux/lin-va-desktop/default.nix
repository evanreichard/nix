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
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "*";
      type = "hard";
      item = "memlock";
      value = "unlimited";
    }
  ];

  nixpkgs.config.allowUnfree = true;

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
      mosh = enabled;
    };

    virtualisation = {
      podman = enabled;
    };
  };

  systemd.services.llama-swap.serviceConfig.LimitMEMLOCK = "infinity";
  services.llama-swap = {
    enable = true;
    openFirewall = true;
    package = pkgs.reichard.llama-swap;
    settings = {
      models = {
        # https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF/tree/main
        "devstral-small-2-instruct" = {
          name = "Devstral Small 2 (24B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/Devstral-Small-2-24B-Instruct-2512-UD-Q4_K_XL.gguf \
              --chat-template-file /mnt/ssd/Models/Devstral-Small-2-24B-Instruct-2512-UD-Q4_K_XL_template.jinja \
              -c 98304 \
              -ctk q8_0 \
              -ctv q8_0 \
              -fit off \
              -dev CUDA0
          '';
        };

        # https://huggingface.co/unsloth/Qwen3-Next-80B-A3B-Instruct-GGUF/tree/main
        "qwen3-next-80b-instruct" = {
          name = "Qwen3 Next (80B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/Qwen3-Next-80B-A3B-Instruct-UD-Q4_K_XL.gguf \
              -c 131072 \
              --temp 0.7 \
              --min-p 0.0 \
              --top-p 0.8 \
              --top-k 20 \
              --repeat-penalty 1.05 \
              -ctk q8_0 \
              -ctv q8_0 \
              -fit off \
              -ncmoe 15 \
              -ts 77,23
          '';
        };

        # https://huggingface.co/unsloth/Qwen3-30B-A3B-Instruct-2507-GGUF/tree/main
        "qwen3-30b-2507-instruct" = {
          name = "Qwen3 2507 (30B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf \
              -c 262144 \
              --temp 0.7 \
              --min-p 0.0 \
              --top-p 0.8 \
              --top-k 20 \
              --repeat-penalty 1.05 \
              -ctk q8_0 \
              -ctv q8_0 \
              -ts 70,30
          '';
        };

        # https://huggingface.co/unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF/tree/main
        "qwen3-coder-30b-instruct" = {
          name = "Qwen3 Coder (30B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf \
              -c 262144 \
              --temp 0.7 \
              --min-p 0.0 \
              --top-p 0.8 \
              --top-k 20 \
              --repeat-penalty 1.05 \
              -ctk q8_0 \
              -ctv q8_0 \
              -ts 70,30
          '';
        };

        # https://huggingface.co/unsloth/Qwen3-30B-A3B-Thinking-2507-GGUF/tree/main
        "qwen3-30b-2507-thinking" = {
          name = "Qwen3 2507 (30B) - Thinking";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/Qwen3-30B-A3B-Thinking-2507-UD-Q4_K_XL.gguf \
              -c 262144 \
              --temp 0.7 \
              --min-p 0.0 \
              --top-p 0.8 \
              --top-k 20 \
              --repeat-penalty 1.05 \
              -ctk q8_0 \
              -ctv q8_0 \
              -ts 70,30
          '';
        };

        # https://huggingface.co/mradermacher/gpt-oss-20b-heretic-v2-i1-GGUF/tree/main
        #  --chat-template-kwargs '{\"reasoning_effort\":\"low\"}'
        "gpt-oss-20b-thinking" = {
          name = "GPT OSS (20B) - Thinking";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/gpt-oss-20b-heretic-v2.i1-MXFP4_MOE.gguf \
              -c 131072 \
              --temp 1.0 \
              --top-p 1.0 \
              --top-k 40 \
              -dev CUDA0
          '';
        };

        # https://huggingface.co/unsloth/Qwen3-VL-8B-Instruct-GGUF/tree/main
        "qwen3-8b-vision" = {
          name = "Qwen3 Vision (8B) - Thinking";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/Qwen3-VL-8B-Instruct-UD-Q4_K_XL.gguf \
              --mmproj /mnt/ssd/Models/Qwen3-VL-8B-Instruct-UD-Q4_K_XL_mmproj-F16.gguf \
              -c 65536 \
              --temp 0.7 \
              --min-p 0.0 \
              --top-p 0.8 \
              --top-k 20 \
              -ctk q8_0 \
              -ctv q8_0 \
              -dev CUDA1
          '';
        };

        # https://huggingface.co/unsloth/Qwen2.5-Coder-7B-Instruct-128K-GGUF/tree/main
        "qwen2.5-coder-7b-instruct" = {
          name = "Qwen2.5 Coder (7B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              -m /mnt/ssd/Models/Qwen2.5-Coder-7B-Instruct-Q8_0.gguf \
              --fim-qwen-7b-default \
              -c 131072 \
              --port ''${PORT} \
              -dev CUDA1
          '';
        };

        # https://huggingface.co/unsloth/Qwen2.5-Coder-3B-Instruct-128K-GGUF/tree/main
        "qwen2.5-coder-3b-instruct" = {
          name = "Qwen2.5 Coder (3B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              -m /mnt/ssd/Models/Qwen2.5-Coder-3B-Instruct-Q8_0.gguf \
              --fim-qwen-3b-default \
              --port ''${PORT} \
              -fit off \
              -dev CUDA1
          '';
        };

        # https://huggingface.co/unsloth/SmolLM3-3B-128K-GGUF/tree/main
        "smollm3-3b-instruct" = {
          name = "SmolLM3(3B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/SmolLM3-3B-128K-UD-Q4_K_XL.gguf \
              -c 98304 \
              --temp 0.6 \
              --top-p 0.95 \
              --reasoning-budget 0 \
              -dev CUDA0
          '';
        };

        # https://huggingface.co/unsloth/ERNIE-4.5-21B-A3B-PT-GGUF/tree/main
        "ernie4.5-21b-instruct" = {
          name = "ERNIE4.5 (21B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/ERNIE-4.5-21B-A3B-PT-UD-Q4_K_XL.gguf \
              -c 98304 \
              --temp 0.7 \
              --min-p 0.0 \
              --top-p 0.8 \
              --top-k 20
          '';
        };

        # https://huggingface.co/mradermacher/OLMoE-1B-7B-0125-Instruct-GGUF/tree/main
        "olmoe-7b-instruct" = {
          name = "OLMoE (7B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/OLMoE-1B-7B-0125-Instruct.Q8_0.gguf \
              -dev CUDA1
          '';
        };

        # https://huggingface.co/gabriellarson/Phi-mini-MoE-instruct-GGUF/tree/main
        "phi-mini-8b-instruct" = {
          name = "Phi mini (8B) - Instruct";
          cmd = ''
            ${pkgs.reichard.llama-cpp}/bin/llama-server \
              --port ''${PORT} \
              -m /mnt/ssd/Models/Phi-mini-MoE-instruct-Q8_0.gguf \
              --repeat-penalty 1.05 \
              --temp 0.0 \
              --top-p 1.0 \
              --top-k 1 \
              -dev CUDA1
          '';
        };
      };
      groups = {
        coding = {
          swap = false;
          exclusive = true;
          members = [
            "devstral-small-2-instruct" # Primary
            "qwen2.5-coder-3b-instruct" # Infill
          ];
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
    reichard.llama-cpp
  ];
}
