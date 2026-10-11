{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.services.airplay;
in
{
  options.${namespace}.services.airplay = {
    enable = lib.mkEnableOption "AirPlay receiver discovery (PipeWire RAOP sink)";
  };

  config = mkIf cfg.enable {
    # Discovery reads each receiver's advertised `et` (encryption) and `cn` (codec)
    # from its mDNS TXT record and picks the handshake itself, so receivers need no
    # per-device config. The ceiling is pairing: PipeWire implements none=0/RSA=1/
    # MFiSAP=4/FairPlay SAPv2.5=5 but no HomeKit SRP, so AirPlay 2 receivers that
    # advertise no usable `et` (e.g. HomePod) will not appear as sinks.
    services.pipewire.extraConfig.pipewire."50-raop" = {
      "context.modules" = [
        {
          name = "libpipewire-module-raop-discover";
          args."stream.rules" = [
            {
              matches = [ { "raop.ip" = "~.*"; } ];
              actions.create-stream."stream.props" = {
                # Volume Scale - WirePlumber stores linear gain; the GUI displays its cube root (0.4³).
                "state.default-volume" = 0.064;
              };
            }
          ];
        }
      ];
    };

    # Receivers push clock-sync and retransmit requests back to the sender's
    # control/timing ports, so these must be reachable even for an outgoing stream.
    services.pipewire.raopOpenFirewall = true;
  };
}
