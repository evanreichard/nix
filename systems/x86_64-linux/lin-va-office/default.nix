{ namespace, pkgs, config, lib, ... }:
let
  inherit (lib.${namespace}) enabled;
  cfg = config.${namespace}.user;
in
{
  system.stateVersion = "25.05";
  time.timeZone = "America/New_York";

  nixpkgs.config.allowUnfree = true;

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
        diskPath = "/dev/sda";
      };
      networking = {
        enable = true;
        useStatic = {
          interface = "enp5s0";
          address = "10.0.50.120";
          defaultGateway = "10.0.50.254";
          nameservers = [ "10.0.20.20" ];
        };
      };
    };

    hardware = {
      opengl = {
        enable = true;
        enableNvidia = true;
      };
    };

    services = {
      openssh = enabled;
      llama-cpp = enabled;
      rtl-tcp = enabled;
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

  # System Packages
  environment.systemPackages = with pkgs; [
    btop
    git
    tmux
    vim
  ];
}
