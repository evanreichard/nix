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
                name = "boot";
                size = "1M";
                type = "EF02";
              };
              esp = {
                name = "ESP";
                size = "500M";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              root = {
                name = "root";
                size = "100%";
                content = {
                  type = "lvm_pv";
                  vg = "pool";
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

      lvm_vg = {
        pool = {
          type = "lvm_vg";
          lvs = {
            root = {
              size = "100%FREE";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [
                  "defaults"
                ];
              };
            };
          };
        };
      };
    };
  };
}
