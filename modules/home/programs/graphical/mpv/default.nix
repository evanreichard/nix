{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.${namespace}.programs.graphical.mpv;
in
{
  options.${namespace}.programs.graphical.mpv = {
    enable = mkEnableOption "mpv with interactive 180°/360° video support";
  };

  config = mkIf cfg.enable {
    programs.mpv = {
      enable = true;
      scripts = [ pkgs.reichard.mpv360 ];
      config.hwdec = "auto-safe";
    };

    xdg.configFile = {
      "mpv/shaders/mpv360.glsl".source = "${pkgs.reichard.mpv360}/share/mpv360/mpv360.glsl";
      "mpv/script-opts/mpv360.conf".source = "${pkgs.reichard.mpv360}/share/mpv360/mpv360.conf";
    };
  };
}
