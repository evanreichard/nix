{ config, pkgs, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  inherit (lib.${namespace}) mkBoolOpt;
  cfg = config.${namespace}.services.rtl-tcp;
in
{
  options.${namespace}.services.rtl-tcp = {
    enable = mkEnableOption "RTL-TCP support";
    openFirewall = mkBoolOpt true "Open firewall";
  };

  config = mkIf cfg.enable {
    hardware.rtl-sdr.enable = true;
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ 1234 ];

    # RTL-SDR TCP Server Service
    systemd.services.rtl-tcp = {
      description = "RTL-SDR TCP Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.rtl-sdr}/bin/rtl_tcp -a 0.0.0.0 -f 1090000000 -s 2400000";
        Restart = "on-failure";
        RestartSec = "10s";
        User = "root";
        Group = "root";
      };
    };
  };
}
