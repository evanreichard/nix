{ config, lib, pkgs, namespace, ... }:
let
  cfg = config.${namespace}.services.swww;
in
{
  options.${namespace}.services.swww = {
    enable = lib.mkEnableOption "swww wallpaper service";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      swww
    ];

    systemd.user = {
      services = {
        swww-daemon = {
          Unit = {
            Description = "SWWW Wallpaper Daemon";
            After = [ "graphical-session.target" ];
          };

          Install = {
            WantedBy = [ "graphical-session.target" ];
          };

          Service = {
            Type = "simple";
            ExecStart = "${pkgs.swww}/bin/swww-daemon";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };

        change-wallpaper = {
          Unit = {
            Description = "SWWW Wallpaper Changer";
            After = [ "swww-daemon.service" ];
            Requires = [ "swww-daemon.service" ];
          };

          Install = {
            WantedBy = [ "swww-daemon.service" ];
          };

          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.writeShellScript "change-wallpaper-script" ''
              WALLPAPER=$(${pkgs.findutils}/bin/find $HOME/Wallpapers -type f | ${pkgs.coreutils}/bin/shuf -n 1)
              ${pkgs.swww}/bin/swww img "$WALLPAPER" --transition-type random
            ''}";
          };
        };
      };

      timers.swww-schedule = {
        Unit = {
          Description = "SWWW Wallpaper Schedule";
        };

        Install = {
          WantedBy = [ "timers.target" ];
        };

        Timer = {
          OnBootSec = "1min";
          OnUnitActiveSec = "1h";
          Unit = "change-wallpaper.service";
        };
      };
    };
  };
}
