{ namespace
, config
, pkgs
, lib
, ...
}:
let
  inherit (lib.${namespace}) enabled;

  nvidia-smi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
  llama-cpp = pkgs.reichard.llama-cpp;
  ik-llama-cpp = pkgs.reichard.ik-llama-cpp;
  stable-diffusion-cpp = pkgs.reichard.stable-diffusion-cpp.override {
    cudaSupport = true;
  };
in
{
  system.stateVersion = "26.05";
  time.timeZone = "America/New_York";
  nixpkgs.config.allowUnfree = true;
  hardware.nvidia-container-toolkit.enable = true;
  programs.nix-ld.enable = true;

  # EVGA iCX3 Sensors - evga-icx talks to the card's microcontroller over I2C to
  # read per-fan RPM and the memory/VRM thermistors, none of which NVML exposes.
  # iomem=relaxed additionally permits the root-only VRAM and hotspot reads.
  boot.kernelModules = [ "i2c-dev" ];
  boot.kernelParams = [ "iomem=relaxed" ];

  # Lets wheel read the sensors without sudo, matching the udev rules OpenRGB
  # ships. This grants access to every I2C bus, not just the GPU's.
  services.udev.extraRules = ''
    KERNEL=="i2c-[0-9]*", GROUP="wheel", MODE="0660"
  '';

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

  # NVIDIA GPU Power Limit
  systemd.services = {
    nvidia-persistence-mode = {
      description = "Enable NVIDIA GPU Persistence Mode";
      after = [ "nvidia-modules-load.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      script = "${nvidia-smi} -pm 1";
    };

    nvidia-power-limit = {
      description = "Set NVIDIA GPU Power Limit";
      after = [ "nvidia-persistence-mode.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      # Target By UUID - nvidia-smi indices follow PCI bus order, so reseating a
      # card silently retargets an index-based limit at the wrong GPU. The UUID
      # is the RTX 3090; the 1080 Ti is left at its stock limit.
      script = "${nvidia-smi} -i GPU-32732286-e9cc-0d35-a72e-4567813a2470 -pl 290";
    };
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
        # GTX 1080 Ti is Pascal; NVIDIA 590+ (nixpkgs stable = 595) dropped Pascal support.
        nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.legacy_580;
      };
    };

    services = {
      openssh = enabled;
      llama-swap = enabled;
      mosh = enabled;
    };

    virtualisation = {
      podman = {
        enable = true;
        enableNvidia = true;
      };
    };

    security = {
      sops = enabled;
    };
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    btop
    git
    tmux
    vim

    # Local Packages
    llama-cpp
    ik-llama-cpp
    stable-diffusion-cpp
    reichard.evga-icx
  ];
}
