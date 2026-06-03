{ namespace
, lib
, modulesPath
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  system.stateVersion = "26.05";
  time.timeZone = "America/New_York";

  programs.nix-ld.enable = true;

  # System Config
  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        silentBoot = true;
      };

      disk = {
        enable = true;
        diskPath = "/dev/vda";
      };

      networking = {
        enable = true;
        useStatic = {
          interface = "enp0s1";
          address = "192.168.64.3";
          defaultGateway = "192.168.64.1";
          nameservers = [ "192.168.64.1" ];
        };
      };
    };

    services = {
      openssh = enabled;
      mosh = enabled;
    };

    virtualisation = {
      podman = enabled;
    };
  };

  # Trust Interface & NAT All Ports
  networking = {
    firewall.trustedInterfaces = [ "enp0s1" ];
    nftables.enable = true;
    nftables.ruleset = ''
      table ip nat {
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
          iifname "enp0s1" meta l4proto tcp dnat ip to 127.0.0.1
          iifname "enp0s1" meta l4proto udp dnat ip to 127.0.0.1
        }
      }
    '';
  };

  # Allow NAT
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.route_localnet" = 1;
  };

  fileSystems."/mnt/host-share" = {
    device = "share";
    fsType = "virtiofs";
    options = [ "defaults" ];
  };
}
