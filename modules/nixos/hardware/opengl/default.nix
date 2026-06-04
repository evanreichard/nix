{ config
, lib
, pkgs
, namespace
, ...
}:
let
  inherit (lib) mkIf mkForce;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.hardware.opengl;
in
{
  options.${namespace}.hardware.opengl = {
    enable = lib.mkEnableOption "support for opengl";
    enable32Bit = mkBoolOpt false "enable 32-bit";
    enableIntel = mkBoolOpt false "support for intel";
    enableNvidia = mkBoolOpt false "support for nvidia";
    nvidiaPackage = lib.mkOption {
      type = lib.types.package;
      default = config.boot.kernelPackages.nvidiaPackages.stable;
      defaultText = "config.boot.kernelPackages.nvidiaPackages.stable";
      description = "nvidia driver package; pin to legacy_580 for Pascal (GTX 10xx) and older";
    };
  };

  config = mkIf cfg.enable {
    services.xserver.videoDrivers = mkIf cfg.enableNvidia [ "nvidia" ];

    environment.systemPackages =
      with pkgs;
      [
        libva-utils
        vdpauinfo
      ]
      ++ lib.optional cfg.enableNvidia nvtopPackages.nvidia
      ++ lib.optional cfg.enableIntel nvtopPackages.intel;

    # Enable Nvidia Hardware
    hardware.nvidia = mkIf cfg.enableNvidia {
      package = cfg.nvidiaPackage;
      modesetting.enable = true;
      powerManagement.enable = true;
      open = false;
      nvidiaSettings = true;
    };

    # Add Intel Arc / Nvidia Drivers
    hardware.enableRedistributableFirmware = mkIf cfg.enableIntel (mkForce true);
    hardware.graphics = {
      enable = true;
      enable32Bit = cfg.enable32Bit;

      extraPackages =
        with pkgs;
        lib.optionals cfg.enableIntel [
          libvdpau-va-gl
          intel-vaapi-driver
          intel-media-driver
          intel-compute-runtime
          intel-ocl
        ]
        ++ lib.optionals cfg.enableNvidia [
          cudatoolkit
        ];
    };
  };
}
