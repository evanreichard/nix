{ config
, lib
, namespace
, pkgs
, ...
}:
let
  inherit (lib.${namespace}) enabled;

  # The attic client Reads $XDG_CONFIG_HOME/attic/config.toml and nothing else, so the rendered
  # template has to be linked into that directory rather than pointed at directly.
  atticConfigHome = "/var/lib/attic-client";
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

  # Host Key Is The Only Identity - sops-install-secrets treats an unreadable `age.keyFile` as
  # fatal while unreadable `age.sshKeyPaths` are skipped with a warning, and this host has neither a
  # user age key nor a user ssh key. The machine key that sealed the secrets is what decrypts them.
  sops.age.keyFile = lib.mkForce null;

  sops.secrets.attic_push_token = { };

  sops.templates."attic-config.toml" = {
    content = ''
      default-server = "attic"
      [servers.attic]
      endpoint = "https://attic.va.reichard.io/"
      token = "${config.sops.placeholder.attic_push_token}"
    '';
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d ${atticConfigHome}/attic 0700 root root -"
    "L+ ${atticConfigHome}/attic/config.toml - - - - ${config.sops.templates."attic-config.toml".path}"
  ];

  # Publishing Is Best-Effort - A cache outage must not fail an otherwise successful build, so a
  # failed push is logged and the build stands. `set -f` and `IFS` are required because the daemon
  # hands the hook a space-separated $OUT_PATHS with no quoting.
  environment.etc."nix/post-build-hook.sh".source = pkgs.writeShellScript "post-build-hook" ''
    set -f
    export IFS=' '
    export XDG_CONFIG_HOME=${atticConfigHome}
    [ -n "''${OUT_PATHS:-}" ] || exit 0
    ${lib.getExe pkgs.attic-client} push nix $OUT_PATHS \
      || echo "attic: failed to push to the binary cache" >&2
  '';

  nix.settings.post-build-hook = "/etc/nix/post-build-hook.sh";

  # System Packages
  environment.systemPackages = with pkgs; [
    attic-client
    btop
    git
    tmux
    vim
  ];
}
