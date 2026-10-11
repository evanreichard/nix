{ config
, pkgs
, lib
, namespace
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.programs.graphical.wms.hyprland;
in
{
  options.${namespace}.programs.graphical.wms.hyprland = {
    enable = lib.mkEnableOption "Hyprland";
    displayManager = lib.mkOption {
      type = lib.types.enum [ "sddm" "greetd" ];
      default = "sddm";
      description = "Display manager for this Hyprland host";
    };
  };

  config = mkIf cfg.enable {
    programs = {
      hyprland = {
        enable = true;
        withUWSM = true;
      };
    };

    environment.systemPackages = with pkgs; [
      wl-clipboard
    ];

    reichard = {
      display-managers = {
        sddm = {
          enable = cfg.displayManager == "sddm";
          scale = "1.25";
        };
        greetd.enable = cfg.displayManager == "greetd";
      };
    };
  };
}
