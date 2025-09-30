{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.hardware.battery.upower;
in
{
  options.${namespace}.hardware.battery.upower = {
    enable = lib.mkEnableOption "enable upower";
  };

  config = mkIf cfg.enable {
    services.upower.enable = true;
  };
}
