{ namespace
, lib
, modulesPath
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  system.stateVersion = "25.11";
  time.timeZone = "America/New_York";

  networking.firewall.trustedInterfaces = [ "enp0s1" ];
  programs.nix-ld.enable = true;

  # System Config
  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        silentBoot = true;
      };

      disk = {
        enable = true;
        diskPath = "/dev/vda";
      };

      networking = {
        enable = true;
        useStatic = {
          interface = "enp0s1";
          address = "192.168.64.3";
          defaultGateway = "192.168.64.1";
          nameservers = [ "192.168.64.1" ];
        };
      };
    };

    services = {
      openssh = enabled;
      mosh = enabled;
    };

    virtualisation = {
      podman = enabled;
    };
  };

  fileSystems."/mnt/host-share" = {
    device = "share";
    fsType = "virtiofs";
    options = [ "defaults" ];
  };

  # fileSystems."/home/evanreichard/Development" = {
  #   device = "/mnt/host-share/Development";
  #   fsType = "none";
  #   options = [ "bind" ];
  #   depends = [ "/mnt/host-share" ];
  # };
}
