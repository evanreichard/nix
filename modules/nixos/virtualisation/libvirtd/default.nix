{ config, lib, pkgs, namespace, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) mkBoolOpt;

  cfg = config.${namespace}.virtualisation.libvirtd;
in
{
  options.${namespace}.virtualisation.libvirtd = {
    enable = lib.mkEnableOption "enable libvirtd";
    withVirtManager = mkBoolOpt false "add virt-manager";
    enableIntelIOMMU = mkBoolOpt false "enable Intel IOMMU for better device passthrough";
    enableAMDIOMMU = mkBoolOpt false "enable AMD IOMMU for better device passthrough";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      win-virtio
      libvirt
      qemu_kvm
    ] ++ lib.optionals cfg.withVirtManager [
      virt-manager
      virt-viewer
      spice-gtk
    ];

    reichard = {
      user = {
        extraGroups = [
          "libvirtd"
        ];
      };
    };

    virtualisation = {
      libvirtd = {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = false;
          swtpm.enable = true;
          ovmf = {
            enable = true;
            packages = [ pkgs.OVMFFull.fd ];
          };
        };
      };

      spiceUSBRedirection.enable = true;
    };

    boot.kernelParams = lib.optionals cfg.enableIntelIOMMU [
      "intel_iommu=on"
    ] ++ lib.optionals cfg.enableAMDIOMMU [
      "amd_iommu=on"
    ];
  };
}
