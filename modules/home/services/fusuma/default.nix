{ config, pkgs, lib, namespace, ... }:
let
  cfg = config.${namespace}.services.fusuma;
in
{
  options.${namespace}.services.fusuma = {
    enable = lib.mkEnableOption "Fusuma";
  };

  config = lib.mkIf cfg.enable {
    services.fusuma = {
      enable = true;
      extraPackages = with pkgs; [ ydotool deterministic-uname uutils-coreutils-noprefix ];
      settings = {
        swipe = {
          "3" = {
            begin = {
              command = "ydotool click 40";
              interval = 0.00;
            };
            update = {
              command = "ydotool mousemove -- $move_x, $move_y";
              interval = 0.01;
              accel = 1.00;
              # accel = 1.70;
            };
            end = {
              command = "ydotool click 80";
            };
          };
        };
      };
    };
  };
}
