{ config, pkgs, ... }:

let
  cuda-llama = (pkgs.llama-cpp.override {
    cudaSupport = true;
  }).overrideAttrs (oldAttrs: {
    cmakeFlags = oldAttrs.cmakeFlags ++ [
      "-DGGML_CUDA_ENABLE_UNIFIED_MEMORY=1"

      # Disable CPU Instructions - Intel(R) Core(TM) i5-3570K CPU @ 3.40GHz
      "-DLLAMA_FMA=OFF"
      "-DLLAMA_AVX2=OFF"
      "-DLLAMA_AVX512=OFF"
      "-DGGML_FMA=OFF"
      "-DGGML_AVX2=OFF"
      "-DGGML_AVX512=OFF"
    ];
  });

  # Define Model Vars
  modelDir = "/models";

  # 7B
  # modelName = "qwen2.5-coder-7b-q8_0.gguf";
  # modelUrl = "https://huggingface.co/ggml-org/Qwen2.5-Coder-7B-Q8_0-GGUF/resolve/main/${modelName}?download=true";

  # 3B
  modelName = "qwen2.5-coder-3b-q8_0.gguf";
  modelUrl = "https://huggingface.co/ggml-org/Qwen2.5-Coder-3B-Q8_0-GGUF/resolve/main/${modelName}?download=true";

  modelPath = "${modelDir}/${modelName}";
in

{
  # Allow Nvidia & CUDA
  nixpkgs.config.allowUnfree = true;

  # Enable Graphics
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ pkgs.cudatoolkit ];
  };

  # Load Nvidia Driver Module
  services.xserver.videoDrivers = [ "nvidia" ];

  # Nvidia Package Configuration
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;
  };

  # Networking Configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      1234 # RTL-TCP
      8080 # LLama API
    ];
  };

  # RTL-SDR
  hardware.rtl-sdr.enable = true;

  systemd.services = {
    # LLama Download Model
    download-model = {
      description = "Download Model";
      wantedBy = [ "multi-user.target" ];
      before = [ "llama-cpp.service" ];
      path = [ pkgs.curl pkgs.coreutils ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        Group = "root";
      };
      script = ''
        set -euo pipefail

        if [ ! -f "${modelPath}" ]; then
          mkdir -p "${modelDir}"
          # Add -f flag to follow redirects and -L for location
          # Add --fail flag to exit with error on HTTP errors
          # Add -C - to resume interrupted downloads
          curl -f -L -C - \
            -H "Accept: application/octet-stream" \
            --retry 3 \
            --retry-delay 5 \
            --max-time 1800 \
            "${modelUrl}" \
            -o "${modelPath}.tmp" && \
          mv "${modelPath}.tmp" "${modelPath}"
        fi
      '';
    };

    # RTL-SDR TCP Server Service
    rtl-tcp = {
      description = "RTL-SDR TCP Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.rtl-sdr}/bin/rtl_tcp -a 0.0.0.0 -f 1090000000 -s 2400000";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "root";
        Group = "root";
      };
    };
  };

  # Setup LLama API Service
  systemd.services.llama-cpp = {
    after = [ "download-model.service" ];
    requires = [ "download-model.service" ];
  };

  # Enable LLama API
  services.llama-cpp = {
    enable = true;
    host = "0.0.0.0";
    package = cuda-llama;
    model = modelPath;
    port = 8080;
    openFirewall = true;

    # 7B
    # extraFlags = [
    #   "-ngl"
    #   "99"
    #   "-fa"
    #   "-ub"
    #   "512"
    #   "-b"
    #   "512"
    #   "-dt"
    #   "0.1"
    #   "--ctx-size"
    #   "4096"
    #   "--cache-reuse"
    #   "256"
    # ];

    # 3B
    extraFlags = [
      "-ngl"
      "99"
      "-fa"
      "-ub"
      "1024"
      "-b"
      "1024"
      "--ctx-size"
      "0"
      "--cache-reuse"
      "256"
    ];
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    htop
    nvtopPackages.full
    rtl-sdr
    tmux
    vim
    wget
  ];
}
