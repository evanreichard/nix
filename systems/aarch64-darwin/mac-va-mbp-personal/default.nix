{ lib, ... }:
{
  system.stateVersion = 6;
  nix.enable = false;

  # System Config
  reichard = {
    nix = {
      enable = true;
      usingDeterminate = true;
    };

    security = {
      sops = {
        enable = true;
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        defaultSopsFile = lib.snowfall.fs.get-file "secrets/mac-va-mbp-personal/default.yaml";
      };
    };
  };
}
