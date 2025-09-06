{ config, lib, namespace, ... }:
let
  inherit (lib) mkIf mkDefault;

  cfg = config.${namespace}.system.boot;
in
{
  options.${namespace}.system.boot = {
    enable = lib.mkEnableOption "Enable Boot";
    xenGuest = lib.mkEnableOption "Enable Xen Guest";
    showNotch = lib.mkEnableOption "Show macOS Notch";
    silentBoot = lib.mkEnableOption "Silent Boot";
  };

  config = mkIf cfg.enable {
    services.xe-guest-utilities.enable = mkIf cfg.xenGuest true;

    boot = {
      kernelParams = lib.optionals cfg.silentBoot [
        "quiet"
        "loglevel=3"
        "udev.log_level=3"
        "rd.udev.log_level=3"
        "systemd.show_status=auto"
        "rd.systemd.show_status=auto"
        "vt.global_cursor_default=0"
      ] ++ lib.optionals cfg.showNotch [
        "apple_dcp.show_notch=1"
      ];

      loader = {
        efi = {
          canTouchEfiVariables = false;
        };

        # systemd-boot = {
        #   enable = true;
        #   configurationLimit = 20;
        #   editor = false;
        # };

        grub = {
          enable = true;
          efiSupport = true;
          efiInstallAsRemovable = true;
        };

        timeout = mkDefault 1;
      };

      initrd = mkIf cfg.xenGuest {
        kernelModules = [ "xen_netfront" "xen_blkfront" ];
        supportedFilesystems = [ "xenfs" ];
      };
      kernelModules = mkIf cfg.xenGuest [ "xen_netfront" "xen_blkfront" "xenfs" ];
    };
  };
}
