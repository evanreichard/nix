{ namespace, config, pkgs, ... }:
let
  cfg = config.${namespace}.user;
in
{
  time.timeZone = "America/New_York";
  system.stateVersion = "24.11";

  reichard = {
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
          address = "10.0.50.130";
          defaultGateway = "10.0.50.254";
          nameservers = [ "10.0.50.254" ];
        };
      };
    };

    services = {
      openssh = {
        enable = true;
        authorizedKeys = [
          # evanreichard@lin-va-mbp-personal
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJJoyXQOv9cAjGUHrUcvsW7vY9W0PmuPMQSI9AMZvNY"
          # evanreichard@lin-va-thinkpad
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAq5JQr/6WJMIHhR434nK95FrDmf2ApW2Ahd2+cBKwDz"
          # NixOS Builder
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDF8QjeN8lpT+Mc70zwEJQqN9W/GKvTOTd32VgfNhVdN"
        ];
      };
    };
  };

  users.users.${cfg.name} = {
    openssh = {
      authorizedKeys.keys = [
        # evanreichard@lin-va-mbp-personal
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJJoyXQOv9cAjGUHrUcvsW7vY9W0PmuPMQSI9AMZvNY"
        # evanreichard@lin-va-thinkpad
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAq5JQr/6WJMIHhR434nK95FrDmf2ApW2Ahd2+cBKwDz"
        # NixOS Builder
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDF8QjeN8lpT+Mc70zwEJQqN9W/GKvTOTd32VgfNhVdN"
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
