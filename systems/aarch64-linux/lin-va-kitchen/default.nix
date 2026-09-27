{ config
, inputs
, lib
, modulesPath
, namespace
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];

  system.stateVersion = "26.05";
  networking.hostName = "lin-va-kitchen";
  time.timeZone = "America/New_York";
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllHardware = lib.mkForce false;
  boot.supportedFilesystems.zfs = lib.mkForce false;
  boot.initrd.includeDefaultModules = false;
  boot.initrd.availableKernelModules = [ "mmc_block" ];
  hardware.raspberry-pi.firmware = {
    enable = true;
    uboot.enable = true;
  };
  fileSystems."/boot/firmware".options = lib.mkForce [ "umask=0077" ];

  sops.secrets = {
    wifi_ssid = { };
    wifi_psk = { };
  };

  reichard = {
    nix = {
      enable = true;
      builderSshKey = "/home/evanreichard/.ssh/id_ed25519";
    };
    security.sops = enabled;

    system.networking = {
      enable = true;
      enableIWD = false;
      wifi = {
        interface = "wlan0";
        ssid = config.sops.placeholder.wifi_ssid;
        psk = config.sops.placeholder.wifi_psk;
      };
    };

    services = {
      avahi = enabled;
      openssh = enabled;
      shairport-sync = {
        enable = true;
        name = "Kitchen Speakers";
        outputDevice = "plughw:CARD=DAC,DEV=0";
      };
    };
  };
}
