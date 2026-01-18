{ config
, lib
, namespace
, ...
}:
let
  inherit (lib) mkIf mkEnableOption types;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.services.printing;
in
{
  options.${namespace}.services.printing = with types; {
    enable = mkEnableOption "enable printing service";
    drivers = mkOpt (listOf package) [ ] "print drivers to use";
  };

  config = mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = cfg.drivers;
    };
  };
}
