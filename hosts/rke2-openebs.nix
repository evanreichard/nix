{ config, pkgs, lib, ... }:

{
  # Node Nix Config
  options = {
    dataDiskID = lib.mkOption {
      type = lib.types.str;
      description = "The device ID for the data disk";
    };
    serverAddr = lib.mkOption {
      type = lib.types.str;
      description = "The server to join";
      default = "";
    };
    networkConfig = lib.mkOption {
      type = lib.types.submodule {
        options = {
          interface = lib.mkOption {
            type = lib.types.str;
            description = "Network interface name";
            example = "enp0s3";
          };
          address = lib.mkOption {
            type = lib.types.str;
            description = "Static IP address";
            example = "10.0.20.200";
          };
          defaultGateway = lib.mkOption {
            type = lib.types.str;
            description = "Default gateway IP";
            example = "10.0.20.254";
          };
          nameservers = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of DNS servers";
            example = [ "10.0.20.254" "8.8.8.8" ];
            default = [ "8.8.8.8" "8.8.4.4" ];
          };
        };
      };
      description = "Network configuration";
    };
  };

  config = {
    # ----------------------------------------
    # ---------- Base Configuration ----------
    # ----------------------------------------

    # OpenEBS Mayastor Requirements
    boot.kernelModules = [ "nvme_tcp" ];
    boot.kernel.sysctl = {
      "vm.nr_hugepages" = 1024;
    };

    # Network Configuration
    networking = {
      hostName = config.hostName;
      networkmanager.enable = false;

      # Interface Configuration
      inherit (config.networkConfig) defaultGateway nameservers;
      interfaces.${config.networkConfig.interface}.ipv4.addresses = [{
        inherit (config.networkConfig) address;
        prefixLength = 24;
      }];

      firewall = {
        enable = true;

        allowedTCPPorts = [
          # RKE2 Ports - https://docs.rke2.io/install/requirements#networking
          6443 # Kubernetes API
          9345 # RKE2 supervisor API
          2379 # etcd Client Port
          2380 # etcd Peer Port
          2381 # etcd Metrics Port
          10250 # kubelet metrics
          9099 # Canal CNI health checks

          # OpenEBS Mayastor - https://openebs.io/docs/user-guides/replicated-storage-user-guide/replicated-pv-mayastor/rs-installation#network-requirements
          10124 # REST API
          8420 # NVMf
          4421 # NVMf
        ];

        allowedUDPPorts = [
          # RKE2 Ports - https://docs.rke2.io/install/requirements#networking
          8472 # Canal CNI with VXLAN
          # 51820 # Canal CNI with WireGuard IPv4 (if using encryption)
          # 51821 # Canal CNI with WireGuard IPv6 (if using encryption)
        ];
      };
    };

    # System Packages
    environment.systemPackages = with pkgs; [
      htop
      k9s
      kubectl
      kubernetes-helm
      nfs-utils
      vim
    ];

    # ----------------------------------------
    # ---------- RKE2 Configuration ----------
    # ----------------------------------------

    # RKE2 Join Token
    environment.etc."rancher/rke2/node-token" = lib.mkIf (config.serverAddr != "") {
      source = ../rke2-token;
      mode = "0600";
      user = "root";
      group = "root";
    };

    # Enable RKE2
    services.rke2 = {
      enable = true;
      role = "server";

      disable = [
        # Disable - Utilizing Traefik
        "rke2-ingress-nginx"

        # Distable - Utilizing OpenEBS's Snapshot Controller
        "rke2-snapshot-controller"
        "rke2-snapshot-controller-crd"
        "rke2-snapshot-validation-webhook"
      ];

      # OpenEBS Scheduleable 
      nodeLabel = [
        "openebs.io/engine=mayastor"
      ];

    } // lib.optionalAttrs (config.serverAddr != "") {
      serverAddr = config.serverAddr;
      tokenFile = "/etc/rancher/rke2/node-token";
    };

    # Bootstrap Kubernetes Manifests
    system.activationScripts.k8s-manifests = {
      deps = [ ];
      text = ''
        mkdir -p /var/lib/rancher/rke2/server/manifests

        # Base Configs
        cp ${../k8s/openebs.yaml} /var/lib/rancher/rke2/server/manifests/openebs-base.yaml
        cp ${../k8s/kasten.yaml} /var/lib/rancher/rke2/server/manifests/kasten-base.yaml

        # OpenEBS Disk Pool
        cp ${pkgs.substituteAll {
          src = ../k8s/openebs-disk-pool.yaml;
          hostName = config.hostName;
          dataDiskID = config.dataDiskID;
        }} /var/lib/rancher/rke2/server/manifests/openebs-disk-pool-${config.hostName}.yaml
      '';
    };
  };
}
