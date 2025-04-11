{ namespace, lib, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = "24.11";
  time.timeZone = "America/New_York";

  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        silentBoot = true;
      };
      networking = enabled;
    };

    hardware = {
      opengl = {
        enable = true;
        enable32Bit = true; # Necessary?
        enableIntel = true;
      };
    };

    services = {
      avahi = enabled;
      ydotool = enabled;
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
