{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.services.avahi;
in
{
  options.${namespace}.services.avahi = {
    enable = lib.mkEnableOption "Avahi";
  };

  config = mkIf cfg.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
        workstation = true;
      };
    };

    # Cloud Init
    systemd.services.avahi-daemon = mkIf config.${namespace}.services.cloud-init.enable {
      after = [ "cloud-final.service" ];
      requires = [ "cloud-final.service" ];
    };
  };
}
