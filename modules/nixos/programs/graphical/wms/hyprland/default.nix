{ config
, pkgs
, lib
, namespace
, ...
}:
let
  cfg = config.${namespace}.programs.graphical.wms.hyprland;
in
{
  options.${namespace}.programs.graphical.wms.hyprland.enable = lib.mkEnableOption "Hyprland";

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    environment.systemPackages = [ pkgs.wl-clipboard ];
    reichard.display-managers.greetd.enable = true;
    reichard.services.shan-shui-lock = {
      enable = true;
      themePackage = config.${namespace}.display-managers.greetd.themePackage;
      palette = config.${namespace}.display-managers.greetd.palette;
    };
  };
}
