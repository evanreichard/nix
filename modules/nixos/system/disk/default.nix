{ config, lib, namespace, ... }:
let
  inherit (lib.${namespace}) mkOpt;
  inherit (lib) mkIf types;

  cfg = config.${namespace}.system.disk;
in
{
  options.${namespace}.system.disk = {
    enable = lib.mkEnableOption "Disko Configuration";
    diskPath = mkOpt types.str null "Device path for the main disk";
  };

  config = mkIf cfg.enable {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          device = cfg.diskPath;
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
              swap = {
                size = "32G";
                content = {
                  type = "swap";
                  discardPolicy = "both";
                  resumeDevice = true;
                };
              };
            };
          };
        };
      };
    };
  };
}
