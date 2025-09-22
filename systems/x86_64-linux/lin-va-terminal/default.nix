{ namespace, pkgs, lib, ... }:
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
          address = "10.0.50.30";
          defaultGateway = "10.0.50.254";
          nameservers = [ "10.0.50.254" ];
        };
      };
    };

    services = {
      openssh = enabled;
      avahi = enabled;
    };

    virtualisation = {
      podman = enabled;
    };
  };
}
