{ lib, config, namespace, ... }:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.direnv;
in
{
  options.${namespace}.programs.terminal.direnv = {
    enable = lib.mkEnableOption "direnv";
  };

  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
