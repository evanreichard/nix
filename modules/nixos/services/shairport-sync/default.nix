{ config, lib, namespace, pkgs, ... }:
let
  inherit (lib.${namespace}) mkOpt;
  inherit (lib) mkIf types;
  cfg = config.${namespace}.services.shairport-sync;
in
{
  options.${namespace}.services.shairport-sync = {
    enable = lib.mkEnableOption "Shairport Sync with AirPlay 2 support";
    name = mkOpt types.str "Shairport Sync" "Advertised AirPlay receiver name.";
    outputDevice = mkOpt types.str "default" "ALSA device used for audio output.";
  };

  config = mkIf cfg.enable {
    services.shairport-sync = {
      enable = true;
      package = pkgs.shairport-sync.override {
        enableAirplay2 = true;
      };
      openFirewall = true;
      settings = {
        general = {
          inherit (cfg) name;
          output_backend = "alsa";
          port = 7000;
        };
        alsa.output_device = cfg.outputDevice;
      };
    };
    systemd.services.nqptp = {
      description = "AirPlay 2 PTP timing";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = lib.getExe pkgs.nqptp;
        DynamicUser = true;
        LimitRTPRIO = 6;
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        Restart = "on-failure";
      };
    };
    systemd.services.shairport-sync = {
      requires = [ "nqptp.service" ];
      after = [ "nqptp.service" ];
    };
    networking.firewall = {
      allowedTCPPorts = [ 3689 7000 ];
      allowedTCPPortRanges = [
        {
          from = 32768;
          to = 60999;
        }
      ];
      allowedUDPPorts = [ 319 320 ];
      allowedUDPPortRanges = [
        {
          from = 6000;
          to = 6009;
        }
        {
          from = 32768;
          to = 60999;
        }
      ];
    };
  };
}
