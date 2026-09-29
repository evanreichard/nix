{ lib
, namespace
, pkgs
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  time.timeZone = "America/New_York";
  system.stateVersion = "26.05";
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  reichard = {
    nix.useRemoteBuilder = false;
    security.sops = enabled;
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

  # Host Key Is The Only Identity - sops-install-secrets treats an unreadable `age.keyFile` as fatal
  # while unreadable `age.sshKeyPaths` are skipped with a warning, and this host has neither a user
  # age key nor a user ssh key. The machine key that sealed the secrets is what decrypts them.
  sops.age.keyFile = lib.mkForce null;

  # System Packages
  environment.systemPackages = with pkgs; [
    attic-client
    btop
    git
    tmux
    vim
  ];
}
