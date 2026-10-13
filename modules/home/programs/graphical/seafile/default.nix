{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption optionals;
  cfg = config.${namespace}.programs.graphical.seafile;
in
{
  options.${namespace}.programs.graphical.seafile = {
    enable = mkEnableOption "Seafile desktop client";
  };

  config = mkIf cfg.enable {
    home.packages = optionals pkgs.stdenv.isLinux [ pkgs.seafile-client ];
  };
}
