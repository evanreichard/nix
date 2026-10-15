{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.${namespace}.programs.graphical.airfry;
in
{
  options.${namespace}.programs.graphical.airfry = {
    enable = mkEnableOption "AirFry AirPlay screen mirroring";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.reichard.airfry ];
  };
}
