{ namespace, lib, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "24.11";
  time.timeZone = "America/New_York";

  # System Config
  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        showNotch = true;
        silentBoot = true;
      };
      networking = {
        enable = true;
        enableIWD = true;
      };
    };

    hardware = {
      opengl = enabled;
      asahi = {
        enable = true;
        enableGPU = true;
        firmwareDirectory = ./firmware;
      };
    };

    services = {
      avahi = enabled;
      ydotool = enabled;
    };

    security = {
      sops = {
        enable = true;
        # sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        defaultSopsFile = lib.snowfall.fs.get-file "secrets/lin-mbp-personal/default.yaml";
      };
    };

    virtualisation = {
      podman = enabled;
    };

    programs = {
      graphical = {
        wms.hyprland = enabled;
      };
    };
  };
}
