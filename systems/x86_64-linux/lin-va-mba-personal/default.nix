{ namespace
, pkgs
, lib
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = "26.05";
  time.timeZone = "America/New_York";

  programs.nix-ld.enable = true;

  # BCM43224 WiFi (2012 MacBook Air) - Driven by the in-tree brcmsmac driver;
  # its firmware ships in the redistributable linux-firmware set above.
  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    cpu.intel.updateMicrocode = true;
  };

  services = {
    xserver.videoDrivers = [ "modesetting" ];
    fwupd.enable = true;
  };

  # System Config
  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        enableGrub = false;
        enableSystemd = true;
        silentBoot = true;
      };
      disk = {
        enable = true;
        diskPath = "/dev/disk/by-id/ata-APPLE_SSD_TS128E_52FS11DIT06Y";
      };
      networking = {
        enable = true;
        enableIWD = true;
      };
    };

    hardware = {
      opengl = {
        enable = true;
        enableIntel = true;
      };
      battery = {
        upower = enabled;
      };
    };

    services = {
      printing = enabled;
      openssh = enabled;
      tailscale = enabled;
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

    security = {
      sops = enabled;
    };
  };
}
