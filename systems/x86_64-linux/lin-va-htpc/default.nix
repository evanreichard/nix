{ namespace
, lib
, pkgs
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = "26.05";
  time.timeZone = "America/New_York";

  users.users.kodi = {
    isNormalUser = true;
    extraGroups = [
      "audio"
      "video"
    ];
  };

  services = {
    xserver.enable = true;
    displayManager = {
      autoLogin = {
        enable = true;
        user = "kodi";
      };
      defaultSession = "kodi";
    };
    xserver.desktopManager.kodi = {
      enable = true;
      package = pkgs.kodi.withPackages (_: [
        pkgs.reichard.jellyfin
        pkgs.reichard.pm4k
      ]);
    };
  };

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

    security = {
      sops = enabled;
    };

    hardware.opengl = {
      enable = true;
      enableIntel = true;
    };

    services = {
      avahi = enabled;
      openssh = enabled;
    };
  };
}
