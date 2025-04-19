{ namespace, lib, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = "24.11";
  time.timeZone = "America/New_York";
  hardware.enableRedistributableFirmware = true;

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
        diskPath = "/dev/nvme0n1";
      };
      networking = {
        enable = true;
        enableIWD = true;
      };
    };

    hardware = {
      opengl = enabled;
    };

    services = {
      avahi = enabled;
      ydotool = enabled;
    };

    virtualisation = {
      podman = enabled;
    };

    programs = {
      graphical = {
        wms.hyprland = enabled;
      };
    };

    # security = {
    #   sops = {
    #     enable = true;
    #     # sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    #     defaultSopsFile = lib.snowfall.fs.get-file "secrets/lin-mbp-personal/default.yaml";
    #   };
    # };
  };
}
