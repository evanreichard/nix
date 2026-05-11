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
  stable-diffusion-cpp = pkgs.reichard.stable-diffusion-cpp.override {
    cudaSupport = true;
  };
in
{
  system.stateVersion = "25.11";
  time.timeZone = "America/New_York";
  nixpkgs.config.allowUnfree = true;
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
      script = "${nvidia-smi} -i 0 -pl 290";
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
    stable-diffusion-cpp
  ];
}
