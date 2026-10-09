{ namespace
, lib
, pkgs
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = "26.05";
  time.timeZone = "America/New_York";

  programs.firejail.enable = true;
  programs.nix-ld.enable = true;

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth.enable = true;
  };

  services = {
    fwupd.enable = true;
    blueman.enable = true;
  };

  reichard = {
    nix = enabled;
    user.extraGroups = [ "dialout" ];

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

    hardware.opengl = enabled;

    services = {
      mounts.enableMedia = true;
      avahi = enabled;
      printing = enabled;
      tailscale = enabled;
      ydotool = enabled;
    };

    security.sops = enabled;

    virtualisation.podman = enabled;

    programs.graphical.wms.hyprland = enabled;
  };

  environment.systemPackages = with pkgs; [
    mosh
    rclone
    unzip
  ];
}
