{ pkgs
, ...
}:
{
  time.timeZone = "America/New_York";
  system.stateVersion = "26.05";
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  reichard = {
    nix.useRemoteBuilder = false;
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
          # NixOS Builder
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDF8QjeN8lpT+Mc70zwEJQqN9W/GKvTOTd32VgfNhVdN"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILxfxLnJc9iYosivDe2YGOFFavaQWul4PBjhW2J9QOfF evanreichard@lin-va-kitchen"
        ];
      };
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
