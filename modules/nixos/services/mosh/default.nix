{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.services.mosh;
in
{
  options.${namespace}.services.mosh = {
    enable = lib.mkEnableOption "mosh support";
  };

  config = mkIf cfg.enable {
    programs.mosh = {
      enable = true;
      openFirewall = true;
    };
  };
}
