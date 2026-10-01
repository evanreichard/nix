{ config, lib, namespace, ... }:
let
  cfg = config.${namespace}.services.mounts;
in
{
  options.${namespace}.services.mounts.enableMedia = lib.mkEnableOption "unRAID media NFS mount";

  config = lib.mkIf cfg.enableMedia {
    fileSystems."/mnt/media" = {
      device = "10.0.50.50:/mnt/user/Media";
      fsType = "nfs";
      options = [
        "nfsvers=4"
        "x-systemd.automount"
        "noauto"
        "nofail"
        "_netdev"
      ];
    };
  };
}
