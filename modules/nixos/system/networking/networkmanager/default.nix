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

      connectionConfig = {
        "connection.mdns" = "2";
      };

      # unmanaged = [
      #   "interface-name:br-*"
      #   "interface-name:rndis*"
      # ]
      # ++ lib.optionals config.${namespace}.virtualisation.podman.enable [ "interface-name:docker*" ]
      # ++ lib.optionals config.${namespace}.virtualisation.kvm.enable [ "interface-name:virbr*" ];
    };
  };
}
