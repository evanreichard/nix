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
        enableGrub = false;
        enableSystemd = true;
        silentBoot = true;
      };

      disk = {
        enable = true;
        diskPath = "/dev/disk/by-id/nvme-KINGSTON_SA2000M8250G_50026B768429D3EB";
      };

      networking = {
        enable = true;
        useStatic = {
          interface = "eno1";
          address = "10.0.20.50";
          defaultGateway = "10.0.20.254";
          nameservers = [ "10.0.20.20" ];
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
      openssh = enabled;
      ydotool = enabled;
      octoprint = {
        enable = true;
        openFirewall = true;
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
