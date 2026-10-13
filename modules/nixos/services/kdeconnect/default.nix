{ config, lib, namespace, ... }:
let
  cfg = config.${namespace}.services.kdeconnect;
in
{
  options.${namespace}.services.kdeconnect = {
    enable = lib.mkEnableOption "KDE Connect";
  };

  config = lib.mkIf cfg.enable {
    programs.kdeconnect.enable = true;
  };
}
