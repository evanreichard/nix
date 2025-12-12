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
      };
    };

    services = {
      openssh = enabled;
      tailscale = {
        enable = true;
        enableRouting = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    btop
    tmux
    vim
  ];
}
