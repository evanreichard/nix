{ config
, lib
, pkgs
, namespace
, ...
}:
let
  cfg = config.${namespace}.services.nunc;
in
{
  options.${namespace}.services.nunc = {
    enable = lib.mkEnableOption "nunc floating clock overlay";

    settings = lib.mkOption {
      type = lib.types.submodule {
        options = {
          fontSize = lib.mkOption {
            type = lib.types.number;
            default = 12;
            description = "Font size for the clock display.";
          };

          verticalPadding = lib.mkOption {
            type = lib.types.number;
            default = 9;
            description = "Vertical padding around the clock text.";
          };

          horizontalPadding = lib.mkOption {
            type = lib.types.number;
            default = 20;
            description = "Horizontal padding around the clock text.";
          };

          position = lib.mkOption {
            type = lib.types.enum [
              "top_left"
              "top_center"
              "top_right"
              "bottom_left"
              "bottom_center"
              "bottom_right"
            ];
            default = "top_right";
            description = "Position of the clock overlay on screen.";
          };

          offsetX = lib.mkOption {
            type = lib.types.number;
            default = -12;
            description = "Horizontal offset from the base position.";
          };

          offsetY = lib.mkOption {
            type = lib.types.number;
            default = 4;
            description = "Vertical offset from the base position.";
          };

          dateFormat = lib.mkOption {
            type = lib.types.str;
            default = "EEE MMM d HH:mm:ss";
            description = "Date format string (NSDateFormatter / Unicode TR35 format).";
          };
        };
      };
      default = { };
      description = "Nunc configuration. Written to ~/.config/nunc/config.json.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "reichard.services.nunc is only supported on macOS (Darwin).";
      }
    ];

    home.packages = [ pkgs.reichard.nunc ];

    home.file.".config/nunc/config.json" = {
      text = builtins.toJSON {
        inherit (cfg.settings)
          fontSize
          verticalPadding
          horizontalPadding
          position
          offsetX
          offsetY
          dateFormat
          ;
      };
    };

    launchd.agents.nunc = {
      enable = true;
      config = {
        Label = "io.reichard.nunc";
        Program = "${pkgs.reichard.nunc}/bin/nunc";
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nunc/nunc.out.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nunc/nunc.err.log";
      };
    };
  };
}
