{ namespace
, pkgs
, lib
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = "25.11";
  time.timeZone = "America/New_York";

  boot = {
    supportedFilesystems = [ "nfs" ];
    kernelParams = [
      # Mask GPE03 (EC wakeup events) to allow hibernation without spurious CPU wakeups
      "acpi_mask_gpe=0x03"
    ];
  };

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
    amdgpu.initrd.enable = lib.mkDefault true;
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
        diskPath = "/dev/nvme0n1";
      };
      networking = {
        enable = true;
        enableIWD = true;
      };
    };

    hardware = {
      opengl = enabled;
      battery = {
        upower = enabled;
      };
    };

    services = {
      openssh = enabled;
      tailscale = enabled;
      avahi = enabled;
      ydotool = enabled;
    };

    virtualisation = {
      podman = enabled;
      libvirtd = {
        enable = true;
        withVirtManager = true;
        enableAMDIOMMU = true;
      };
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

  # Additional System Packages
  environment.systemPackages = with pkgs; [
    dool
    jq
    mosh
    rclone
    sqlite-interactive
    unzip
  ];
}
