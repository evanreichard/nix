{ config
, lib
, pkgs
, namespace
, ...
}:
let
  cfg = config.${namespace}.services.awww;
in
{
  options.${namespace}.services.awww = {
    enable = lib.mkEnableOption "awww wallpaper service";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      awww
    ];

    systemd.user = {
      services = {
        awww-daemon = {
          Unit = {
            Description = "AWWW Wallpaper Daemon";
            After = [ "graphical-session.target" ];
          };

          Install = {
            WantedBy = [ "graphical-session.target" ];
          };

          Service = {
            Type = "simple";
            ExecStart = "${pkgs.awww}/bin/awww-daemon";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };

        change-wallpaper = {
          Unit = {
            Description = "AWWW Wallpaper Changer";
            After = [ "awww-daemon.service" ];
            Requires = [ "awww-daemon.service" ];
          };

          Install = {
            WantedBy = [ "awww-daemon.service" ];
          };

          Service = {
            Type = "oneshot";
            ExecStart = "${pkgs.writeShellScript "change-wallpaper-script" ''
              WALLPAPER=$(${pkgs.findutils}/bin/find $HOME/Wallpapers -type f | ${pkgs.coreutils}/bin/shuf -n 1)
              ${pkgs.awww}/bin/awww img "$WALLPAPER" --transition-type random
            ''}";
          };
        };
      };

      timers.awww-schedule = {
        Unit = {
          Description = "AWWW Wallpaper Schedule";
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
