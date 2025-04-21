{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.graphical.gimp;
in
{
  options.${namespace}.programs.graphical.gimp = {
    enable = mkEnableOption "GIMP";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      gimp-with-plugins
    ];
  };
}
