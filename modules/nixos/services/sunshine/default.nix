{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.services.sunshine;
in
{
  options.${namespace}.services.sunshine = {
    enable = mkEnableOption "enable sunshine service";
    openFirewall = mkBoolOpt true "open firewall";
  };

  config = mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      openFirewall = cfg.openFirewall;
    };
  };
}
