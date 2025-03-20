{ pkgs, lib, modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];
  config = {
    # Basic System
    system.stateVersion = "24.11";
    nix.settings.experimental-features = [ "nix-command" "flakes" ];
    time.timeZone = "UTC";

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    boot = {
      initrd = {
        availableKernelModules = [
          # Xen
          "xen_blkfront"
          "xen_netfront"
        ];
        kernelModules = [ "xen_netfront" "xen_blkfront" ];
        supportedFilesystems = [ "ext4" "xenfs" ];
      };
      kernelModules = [
        # Xen VM Requirements
        "xen_netfront"
        "xen_blkfront"
        "xenfs"

        # iSCSI
        "iscsi_tcp"
      ];
    };

    # Add Intel Arc A310 GPU Drivers
    nixpkgs.config.allowUnfree = true;
    hardware.enableRedistributableFirmware = true;
    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        libvdpau-va-gl
        intel-vaapi-driver
        intel-media-driver
        intel-compute-runtime
        intel-ocl
      ];
    };

    # Network Configuration
    networking = {
      hostName = lib.mkForce "";
      useNetworkd = true;
      useDHCP = false;

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
        ];

        allowedUDPPorts = [
          # RKE2 Ports - https://docs.rke2.io/install/requirements#networking
          8472 # Canal CNI with VXLAN
          # 51820 # Canal CNI with WireGuard IPv4 (if using encryption)
          # 51821 # Canal CNI with WireGuard IPv6 (if using encryption)
        ];

        # Allow Multicast
        extraCommands = ''
          iptables -A INPUT -m pkttype --pkt-type multicast -j ACCEPT
        '';
      };
    };

    services = {
      # Enable Xen Guest Utilities
      xe-guest-utilities.enable = true;

      # Enable iSCSI
      openiscsi = {
        enable = true;
        name = "iqn.2025.placeholder:initiator"; # Overridden @ Runtime
      };

      # Cloud Init
      cloud-init = {
        enable = true;
        network.enable = true;
        settings = {
          datasource_list = [ "NoCloud" ];
          preserve_hostname = false;
          system_info.distro = "nixos";
          system_info.network.renderers = [ "networkd" ];
        };
      };

      # Enable SSH
      openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "prohibit-password";
        };
      };

      # Enable RKE2
      rke2 = {
        enable = true;
        disable = [ "rke2-ingress-nginx" ];
      };
    };

    systemd.services = {
      # RKE2 - Wait Cloud Init
      rke2-server = {
        after = [ "cloud-final.service" ];
        requires = [ "cloud-final.service" ];
      };

      # Runtime iSCSI Initiator Setup
      iscsi-initiator-setup = {
        description = "Setup iSCSI Initiator Name";
        requires = [ "cloud-final.service" ];
        before = [ "iscsid.service" ];
        after = [ "cloud-final.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        path = [ pkgs.hostname pkgs.util-linux ];
        script = ''
          mkdir -p /run/iscsi
          echo "InitiatorName=iqn.2025.org.nixos:$(hostname)" > /run/iscsi/initiatorname.iscsi
          mount --bind /run/iscsi/initiatorname.iscsi /etc/iscsi/initiatorname.iscsi
        '';
      };
    };

    # User Authorized Keys
    users.users.root = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIe1n9l9pVF5+kjWJCOt3AvBVf1HOSZkEDZxCWVPSIkr evan@reichard"
      ];
      hashedPassword = null;
    };

    # Add Symlinks Expected by Democratic
    system.activationScripts = {
      iscsi-initiator = ''
        mkdir -p /usr/bin
        ln -sf ${pkgs.openiscsi}/bin/iscsiadm /usr/bin/iscsiadm
        ln -sf ${pkgs.openiscsi}/bin/iscsid /usr/bin/iscsid
      '';
    };

    # System Packages
    environment = {
      systemPackages = with pkgs; [
        htop
        intel-gpu-tools
        k9s
        kubectl
        kubernetes-helm
        nfs-utils
        openiscsi
        tmux
        vim
      ];

      # Don't Manage - Runtime Generation
      etc."iscsi/initiatorname.iscsi".enable = false;
    };
  };
}
