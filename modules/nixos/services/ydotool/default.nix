{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.services.ydotool;
in
{
  options.${namespace}.services.ydotool = {
    enable = lib.mkEnableOption "ydotool";
  };

  config = mkIf cfg.enable {
    reichard.user.extraGroups = [ "input" ];
    programs.ydotool = {
      enable = true;
      group = "input";
    };
  };
}
