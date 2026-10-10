{ config
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib) mkIf types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.display-managers.sddm;
in
{
  options.${namespace}.display-managers.sddm = {
    enable = lib.mkEnableOption "sddm";
    scale = mkOpt types.str "1.75" "Scale";
    theme = {
      name = mkOpt types.str "catppuccin-mocha-mauve" "SDDM theme name";
      package = mkOpt types.package pkgs.catppuccin-sddm "SDDM theme package";
      extraPackages = mkOpt (types.listOf types.package) [ ] "Extra Qt packages required by the SDDM theme";
    };
  };

  config = mkIf cfg.enable {
    services = {
      displayManager = {
        sddm = {
          inherit (cfg) enable;
          package = pkgs.kdePackages.sddm;
          theme = cfg.theme.name;
          extraPackages = cfg.theme.extraPackages;
          wayland.enable = true;
        };
      };
    };

    environment.systemPackages = [ cfg.theme.package ];

    environment.sessionVariables = {
      QT_SCREEN_SCALE_FACTORS = cfg.scale;
    };
  };
}
