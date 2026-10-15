{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption optionals;
  cfg = config.${namespace}.programs.graphical.doubletake;
in
{
  options.${namespace}.programs.graphical.doubletake = {
    enable = mkEnableOption "Doubletake AirPlay screen mirroring";
    tray = mkEnableOption "Doubletake discovery and mirroring tray";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.reichard.doubletake ] ++ optionals cfg.tray [ pkgs.reichard.doubletake-tray ];

    xdg.desktopEntries."io.reichard.DoubletakeTray" = mkIf cfg.tray {
      name = "AirPlay Mirroring";
      comment = "Discover AirPlay receivers and mirror your screen with Doubletake";
      exec = "${pkgs.systemd}/bin/systemctl --user start doubletake-tray.service";
      icon = "video-display";
      terminal = false;
      categories = [ "AudioVideo" "Network" ];
    };

    systemd.user.services = mkIf cfg.tray {
      doubletake = {
        Unit = {
          Description = "Doubletake AirPlay mirroring daemon";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.reichard.doubletake}/bin/doubletake -daemonize";
          Restart = "on-failure";
          RestartSec = 2;
          TimeoutStopSec = 15;
        };
      };

      doubletake-tray = {
        Unit = {
          Description = "Doubletake AirPlay discovery tray";
          After = [ "graphical-session.target" "doubletake.service" ];
          Wants = [ "doubletake.service" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.reichard.doubletake-tray}/bin/doubletake-tray";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
