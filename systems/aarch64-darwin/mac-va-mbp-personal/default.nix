{ lib, namespace, ... }:
let
  inherit (lib.${namespace}) enabled;
in
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
      sops = enabled;
    };
  };
}
