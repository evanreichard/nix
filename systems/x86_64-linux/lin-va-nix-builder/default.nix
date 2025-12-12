{ pkgs
, ...
}:
{
  time.timeZone = "America/New_York";
  system.stateVersion = "25.11";

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
          # NixOS Builder
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDF8QjeN8lpT+Mc70zwEJQqN9W/GKvTOTd32VgfNhVdN"
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
