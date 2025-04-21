{ config, pkgs, lib, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.programs.graphical.wms.hyprland;
in
{
  options.${namespace}.programs.graphical.wms.hyprland = {
    enable = lib.mkEnableOption "Hyprland";
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
          enable = true;
        };
      };
    };
  };
}
