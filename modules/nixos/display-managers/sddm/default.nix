{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.display-managers.sddm;
in
{
  options.${namespace}.display-managers.sddm = {
    enable = lib.mkEnableOption "sddm";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      catppuccin-sddm
    ];

    services = {
      displayManager = {
        sddm = {
          inherit (cfg) enable;
          package = pkgs.kdePackages.sddm;
          theme = "catppuccin-mocha";
          wayland.enable = true;
        };
      };
    };

    environment.sessionVariables = {
      QT_SCREEN_SCALE_FACTORS = "2";
      QT_FONT_DPI = "192";
    };
  };
}
