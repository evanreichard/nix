{ namespace, lib, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = 6;

  # System Config
  reichard = {
    nix = enabled;

    security = {
      sops = {
        enable = true;
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        defaultSopsFile = lib.snowfall.fs.get-file "secrets/mac-va-mbp-personal/default.yaml";
      };
    };
  };
}
