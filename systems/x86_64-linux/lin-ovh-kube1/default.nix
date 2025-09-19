{ namespace, config, pkgs, lib, modulesPath, ... }:
let
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.user;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  system.stateVersion = "25.05";
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

  users.users.${cfg.name} = {
    openssh = {
      authorizedKeys.keys = [
        # evanreichard@lin-va-mbp-personal
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJJoyXQOv9cAjGUHrUcvsW7vY9W0PmuPMQSI9AMZvNY"
        # evanreichard@mac-va-mbp-personal
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMWj6rd6uDtHj/gGozgIEgxho/vBKebgN5Kce/N6vQWV"
        # evanreichard@lin-va-thinkpad
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAq5JQr/6WJMIHhR434nK95FrDmf2ApW2Ahd2+cBKwDz"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    btop
    tmux
    vim
  ];
}
