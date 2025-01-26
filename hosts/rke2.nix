{ config, pkgs, ... }:

{
  imports = [
    ../k8s
  ];
  k8s.manifestsDir = "/var/lib/rancher/rke2/server/manifests";

  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # System Configuration
  boot.kernelModules = [ "nvme_tcp" ]; # OpenEBS Mayastor Requirement
  boot.kernel.sysctl = {
    "vm.nr_hugepages" = 1024;
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  # Disk Configuration
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "512M";
              type = "EF00"; # EFI
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };

  # Network Configuration
  networking = {
    networkmanager.enable = true;
    firewall = {
      enable = true;

      # https://docs.rke2.io/install/requirements#networking
      allowedTCPPorts = [
        # K8s Control Plane
        6443 # Kubernetes API
        9345 # RKE2 supervisor API
        2379 # etcd Client Port
        2380 # etcd Peer Port
        2381 # etcd Metrics Port

        # K8s Node Communication
        10250 # kubelet metrics
        9099 # Canal CNI health checks

        # OpenEBS Mayastor
        10124 # Mayastor REST API
        8420 # NVMf
        4421 # NVMf
      ];

      allowedUDPPorts = [
        8472 # Canal CNI with VXLAN
        # 51820 # Canal CNI with WireGuard IPv4 (if using encryption)
        # 51821 # Canal CNI with WireGuard IPv6 (if using encryption)
      ];
    };
  };

  # Enable RKE2
  services.rke2 = {
    enable = true;

    disable = [
      # Utilize Traefik
      "rke2-ingress-nginx"

      # Utilize OpenEBS's Snapshot Controller
      "rke2-snapshot-controller"
      "rke2-snapshot-controller-crd"
      "rke2-snapshot-validation-webhook"
    ];

    nodeLabel = [
      "openebs.io/engine=mayastor"
    ];

    role = "server";
    # -------------------
    # --- Server Node ---
    # -------------------

    # -------------------
    # --- Worker Node ---
    # -------------------
    # role = "agent";
    # serverAddr = "https://10.0.0.10:6443"
    # tokenFile = "";
    # agentTokenFile = "";
  };

  # Enable SSH Server
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # Disable Password Login
      PermitRootLogin = "prohibit-password"; # Disable Password Login
    };
  };

  # User Configuration
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEA8P84lWL/p13ZBFNwITm/dLWWL8s9pVmdOImM5gaJAiTLY+DheUvG6YsveB2/5STseiJ34g7Na9TW1mtTLL8zDqPvj3NbprQiYlLJKMbCk6dtfdD4nLMHl8B48e1h699XiZDp2/c+jJb0MkLOFrps+FbPqt7pFt1Pj29tFy8BCg0LGndu6KO+HqYS+aM5tp5hZESo1RReiJ8aHsu5X7wW46brN4gfyyu+8X4etSZAB9raWqlln9NKK7G6as6X+uPypvSjYGSTC8TSePV1iTPwOxPk2+1xBsK7EBLg3jNrrYaiXLnZvBOOhm11JmHzqEJ6386FfQO+0r4iDVxmvi+ojw== rsa-key-20141114"
    ];
    hashedPassword = null; # Disable Password Login
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

  # System State Version
  system.stateVersion = "24.11";
}
