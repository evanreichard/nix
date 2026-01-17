{ config, lib, inputs, namespace, ... }:
let
  inherit (lib) types optionalAttrs;
  inherit (lib.${namespace}) mkOpt;

  cfg = config.${namespace}.hardware.asahi;
in
{
  imports = [
    inputs.apple-silicon.nixosModules.default
  ];

  options.${namespace}.hardware.asahi = {
    enable = lib.mkEnableOption "support for asahi linux";
    firmwareDirectory = mkOpt types.path null "firmware directory";
  };

  config = {
    hardware.asahi = {
      enable = cfg.enable;
    } // optionalAttrs cfg.enable {
      peripheralFirmwareDirectory = cfg.firmwareDirectory;
    };
  };
}
