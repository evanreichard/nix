{ namespace
, lib
, pkgs
, inputs
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      avd-fw = inputs.nixpkgs-unstable.legacyPackages.${prev.system}.avd-fw;
    })
  ];

  imports = [
    ./hardware-configuration.nix
  ];

  system.stateVersion = "26.05";
  time.timeZone = "America/New_York";

  programs.firejail.enable = true;
  programs.nix-ld.enable = true;

  # Asahi Wi-Fi Resume Bug - The Broadcom driver can fail to reconnect after suspend on this MacBook.
  powerManagement.resumeCommands = ''
    ${pkgs.kmod}/bin/modprobe -r brcmfmac_wcc 2>/dev/null || true
    ${pkgs.kmod}/bin/modprobe -r brcmfmac 2>/dev/null || true
    ${pkgs.kmod}/bin/modprobe brcmfmac
    ${pkgs.systemd}/bin/systemctl restart NetworkManager.service
  '';

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # System Config
  reichard = {
    nix = enabled;
    user.extraGroups = [ "dialout" ];

    system = {
      boot = {
        enable = true;
        showNotch = true;
        silentBoot = true;
      };
      networking = {
        enable = true;
        enableIWD = true;
      };
    };

    hardware = {
      opengl = enabled;
      asahi = {
        enable = true;
        firmwareDirectory = ./firmware;
      };
    };

    services = {
      mounts.enableMedia = true;
      avahi = enabled;
      printing = enabled;
      tailscale = enabled;
      ydotool = enabled;
    };

    security = {
      sops = enabled;
    };

    virtualisation = {
      podman = enabled;
    };

    programs = {
      graphical = {
        wms.hyprland = enabled;
      };
    };
  };

  # Additional System Packages
  environment.systemPackages = with pkgs; [
    mosh
    rclone
    unzip
  ];
}
