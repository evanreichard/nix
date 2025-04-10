{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.hardware.opengl;
in
{
  options.${namespace}.hardware.opengl = {
    enable = lib.mkEnableOption "support for opengl";
    enable32Bit = mkBoolOpt false "enable 32-bit";
    enableIntel = mkBoolOpt false "support for intel";
    enableNvidia = mkBoolOpt false "support for nvidia";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      libva-utils
      vdpauinfo
    ] ++ lib.optionals cfg.enableNvidia [
      nvtopPackages.full
    ] ++ lib.optionals cfg.enableIntel [
      intel-gpu-tools
    ];

    # Add Intel Arc / Nvidia Drivers
    hardware.enableRedistributableFirmware = cfg.enableIntel;
    hardware.graphics = {
      enable = true;
      enable32Bit = cfg.enable32Bit;

      extraPackages = with pkgs;
        lib.optionals cfg.enableIntel [
          libvdpau-va-gl
          intel-vaapi-driver
          intel-media-driver
          intel-compute-runtime
          intel-ocl
        ] ++ lib.optionals cfg.enableNvidia [
          cudatoolkit
        ];
    };
  };
}
