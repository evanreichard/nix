{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.services.cloud-init;
in
{
  options.${namespace}.services.cloud-init = {
    enable = lib.mkEnableOption "Enable Cloud-Init";
  };

  config = mkIf cfg.enable {
    services.cloud-init = {
      enable = true;
      network.enable = true;
      settings = {
        datasource_list = [ "NoCloud" ];
        preserve_hostname = false;
        system_info = {
          distro = "nixos";
          network.renderers = [ "networkd" ];
        };
      };
    };
    networking.hostName = lib.mkForce "";
  };
}
