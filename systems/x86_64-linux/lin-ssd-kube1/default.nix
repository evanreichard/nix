{ namespace
, pkgs
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
  time.timeZone = "UTC";

  networking.firewall.allowedTCPPorts = [ 443 ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  reichard = {
    nix = enabled;

    system = {
      disk = {
        enable = true;
        diskPath = "/dev/sda";
      };
      networking = {
        enable = true;
        useStatic = {
          interface = "enp3s0";
          address = "23.29.118.42";
          defaultGateway = "23.29.118.1";
          nameservers = [ "1.1.1.1" ];
        };
      };
    };

    services = {
      openssh = enabled;
      tailscale = {
        enable = true;
        enableRouting = true;
      };
      rke2 = {
        enable = true;
        openFirewall = false;
        disable = [ "rke2-ingress-nginx" ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    btop
    tmux
    vim
  ];
}
