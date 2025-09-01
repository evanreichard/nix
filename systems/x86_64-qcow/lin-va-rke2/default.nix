{ namespace, lib, modulesPath, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  config = {
    # Basic System
    system.stateVersion = "25.05";
    time.timeZone = "UTC";

    reichard = {
      nix = enabled;

      system = {
        boot = {
          enable = true;
          xenGuest = true;
        };
        networking = {
          enable = true;
          useDHCP = false;
          useNetworkd = true;
        };
      };

      services = {
        avahi = enabled;
        openssh = enabled;
        cloud-init = enabled;
        rke2 = {
          enable = true;
          disable = [ "rke2-ingress-nginx" ];
        };
        openiscsi = {
          enable = true;
          symlink = true;
        };
      };

      hardware = {
        opengl = {
          enable = true;
          enableIntel = true;
        };
      };
    };
  };
}
