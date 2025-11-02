{ namespace, lib, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = "25.05";
  time.timeZone = "America/New_York";
  boot.supportedFilesystems = [ "nfs" ];

  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        enableGrub = false;
        enableSystemd = true;
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
          address = "10.0.50.30";
          defaultGateway = "10.0.50.254";
          nameservers = [ "10.0.20.20" ];
        };
      };
    };

    services = {
      avahi = enabled;
      mosh = enabled;
      openssh = enabled;
      tailscale = enabled;
    };

    virtualisation = {
      podman = enabled;
    };
  };
}
