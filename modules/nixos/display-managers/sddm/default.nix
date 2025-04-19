{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.display-managers.sddm;
in
{
  options.${namespace}.display-managers.sddm = {
    enable = lib.mkEnableOption "sddm";
    scale = mkOpt types.str "1.5" "Scale";
  };

  config = mkIf cfg.enable {
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

    environment.systemPackages = with pkgs; [
      catppuccin-sddm
    ];

    environment.sessionVariables = {
      QT_SCREEN_SCALE_FACTORS = cfg.scale;
      #   QT_FONT_DPI = "192";
    };
  };
}
