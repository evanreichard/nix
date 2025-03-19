{ config, lib, ... }:
{
  # NixOS Config
  options = {
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The node hostname";
    };
    enableXenGuest = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable Xen guest support";
    };
    network = lib.mkOption {
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
      default = null;
      description = "Network configuration";
    };
  };

  config = lib.mkMerge [
    {
      # Basic System
      system.stateVersion = "24.11";
      nix.settings.experimental-features = [ "nix-command" "flakes" ];
      networking.hostName = config.hostName;

      # Boot Loader Options
      boot.loader = {
        systemd-boot.enable = true;
        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot";
        };
      };

      # Enable SSH
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "prohibit-password";
        };
      };

      # User Authorized Keys
      users.users.root = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIe1n9l9pVF5+kjWJCOt3AvBVf1HOSZkEDZxCWVPSIkr evan@reichard"
        ];
        hashedPassword = null;
      };
    }

    # Network Configuration
    (lib.mkIf (config.network != null) {
      networking = {
        inherit (config.network) defaultGateway nameservers;
        interfaces.${config.network.interface}.ipv4.addresses = [{
          inherit (config.network) address;
          prefixLength = 24;
        }];
      };
    })

    # Xen Guest Configuration
    (lib.mkIf config.enableXenGuest {
      services.xe-guest-utilities.enable = true;

      boot.initrd = {
        availableKernelModules = [ "xen_blkfront" "xen_netfront" ];
        kernelModules = [ "xen_netfront" "xen_blkfront" ];
        supportedFilesystems = [ "ext4" "xenfs" ];
      };

      boot.kernelModules = [ "xen_netfront" "xen_blkfront" "xenfs" ];
    })
  ];
}
