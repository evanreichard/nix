{ namespace
, config
, pkgs
, lib
, modulesPath
, ...
}:
let
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.user;
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
      networking = enabled;
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
