{ namespace, lib, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "25.11";
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
        defaultSopsFile = lib.snowfall.fs.get-file "secrets/lin-va-mbp-personal/default.yaml";
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
