{ namespace
, lib
, pkgs
, ...
}:
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
        firmwareDirectory = ./firmware;
      };
    };

    services = {
      avahi = enabled;
      printing = enabled;
      tailscale = enabled;
      ydotool = enabled;
    };

    security = {
      sops = enabled;
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

  # Additional System Packages
  environment.systemPackages = with pkgs; [
    mosh
    rclone
    unzip
  ];
}
