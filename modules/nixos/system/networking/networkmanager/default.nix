{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.system.networking;
in
{
  config = mkIf cfg.enable {
    reichard.user.extraGroups = [ "networkmanager" ];

    networking.networkmanager = {
      enable = true;
      wifi.backend = mkIf cfg.enableIWD "iwd";
      unmanaged = lib.optionals (cfg.wifi != null) [
        "interface-name:${cfg.wifi.interface}"
      ];

      connectionConfig = {
        "connection.mdns" = "2";
      };

    };
  };
}
