{ namespace, lib, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  system.stateVersion = "26.05";
  time.timeZone = "America/New_York";

  # Config Boot
  boot = {
    loader.timeout = lib.mkForce 0;
    consoleLogLevel = 7;

    kernelParams = [
      "console=hvc0"
      "console=tty0"
      "loglevel=7"
      "debug"
    ];

    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_console"
      "virtio_net"
      "virtiofs"
    ];
  };

  # Mount Share
  fileSystems."/mnt/dev" = {
    device = "dev-share";
    fsType = "virtiofs";
  };

  reichard = {
    nix = enabled;

    system = {
      boot = {
        enable = true;
        enableGrub = true;
      };

      networking = enabled;
    };

    services = {
      avahi = enabled;
      mosh = enabled;
      openssh = enabled;
      tailscale = enabled;
    };

    virtualisation = {
      podman = enabled;
    };
  };
}
