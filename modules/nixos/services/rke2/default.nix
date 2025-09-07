{ config, pkgs, lib, namespace, ... }:
let
  inherit (lib) types mkIf;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.rke2;
in
{
  options.${namespace}.services.rke2 = with types; {
    enable = lib.mkEnableOption "Enable RKE2";
    disable = mkOpt (listOf str) [ ] "Disable services";
    openFirewall = mkBoolOpt false "Open firewall";
  };

  config = mkIf cfg.enable {
    services.rke2 = {
      enable = true;
      disable = cfg.disable;
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [
      # RKE2 Ports - https://docs.rke2.io/install/requirements#networking
      6443 # Kubernetes API
      9345 # RKE2 supervisor API
      2379 # etcd Client Port
      2380 # etcd Peer Port
      2381 # etcd Metrics Port
      10250 # kubelet metrics
      9099 # Canal CNI health checks

      # MetalLB
      7946 # memberlist
    ];

    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [
      # RKE2 Ports - https://docs.rke2.io/install/requirements#networking
      8472 # Canal CNI with VXLAN
      # 51820 # Canal CNI with WireGuard IPv4 (if using encryption)
      # 51821 # Canal CNI with WireGuard IPv6 (if using encryption)

      # MetalLB
      7946 # memberlist
    ];

    # Cloud Init
    systemd.services.rke2-server = mkIf config.${namespace}.services.cloud-init.enable {
      after = [ "cloud-final.service" ];
      requires = [ "cloud-final.service" ];
    };

    environment.systemPackages = with pkgs; [
      k9s
      kubectl
      nfs-utils
    ];
  };
}
