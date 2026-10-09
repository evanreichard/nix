{ namespace
, inputs
, lib
, pkgs
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  system.stateVersion = "26.05";

  programs.firejail.enable = true;
  programs.nix-ld.enable = true;
  boot.zswap.enable = true;
  boot.kernel.sysctl."vm.swappiness" = 100;

  hardware = {
    enableRedistributableFirmware = true;
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  services = {
    automatic-timezoned.enable = true;
    fstrim.enable = true;
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
        swapSize = "48G";
      };
      networking = {
        enable = true;
        enableIWD = true;
      };
    };

    hardware.opengl = {
      enable = true;
      enable32Bit = true;
    };

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
