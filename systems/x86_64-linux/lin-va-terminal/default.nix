{ namespace, lib, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = "25.05";
  time.timeZone = "America/New_York";

  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        xenGuest = true;
      };

      disk = {
        enable = true;
        diskPath = "/dev/xvda";
      };

      networking = {
        enable = true;
        useStatic = {
          interface = "enX0";
          address = "10.0.50.240";
          defaultGateway = "10.0.50.254";
          nameservers = [ "10.0.50.254" ];
        };
      };
    };

    hardware = {
      opengl = {
        enable = true;
        enable32Bit = true;
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
