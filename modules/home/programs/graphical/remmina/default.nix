{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.graphical.remmina;
in
{
  options.${namespace}.programs.graphical.remmina = {
    enable = mkEnableOption "Remmina";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      remmina
    ];
  };
}
