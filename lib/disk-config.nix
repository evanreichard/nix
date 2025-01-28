{ config, lib, ... }: {
  options = {
    mainDiskID = lib.mkOption {
      type = lib.types.str;
      description = "Device path for the main disk";
      example = "/dev/disk/by-id/ata-VBOX_HARDDISK_VBcd9425b8-d666f9b8";
    };
  };

  config = {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = config.mainDiskID;
          content = {
            type = "gpt";
            partitions = {
              boot = {
                size = "512M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "umask=0077" ];
                };
              };
              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };
    };
  };
}
