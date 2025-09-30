{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.services.poweralertd;
in
{
  options.${namespace}.services.poweralertd = {
    enable = lib.mkEnableOption "poweralertd";
  };

  config = mkIf cfg.enable {
    services.poweralertd = {
      enable = true;
    };
  };
}
