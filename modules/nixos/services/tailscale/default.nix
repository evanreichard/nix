{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.${namespace}.services.tailscale;
in
{
  options.${namespace}.services.tailscale = {
    enable = mkEnableOption "enable tailscale service";
    enableRouting = mkEnableOption "enable tailscale routing";
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = if cfg.enableRouting then "server" else "client";
    };

    boot.kernel.sysctl = mkIf cfg.enableRouting {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # NOTE: Tailscale & K8s Calico conflict due to FWMask. You need to update the DaemonSet Env with:
    #   - name: FELIX_IPTABLESMARKMASK
    #     value: "0xff00ff00"
  };
}
