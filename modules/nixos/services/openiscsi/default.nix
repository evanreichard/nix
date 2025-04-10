{ config, pkgs, lib, namespace, host, ... }:
let
  inherit (lib) types mkIf;
  inherit (lib.${namespace}) mkOpt mkBoolOpt;

  cfg = config.${namespace}.services.openiscsi;
  cloudInitEnabled = config.${namespace}.services.cloud-init.enable;
in
{
  options.${namespace}.services.openiscsi = {
    enable = lib.mkEnableOption "Open iSCSI support";
    name = mkOpt types.str "iqn.2025.reichard.io:${host}" "iSCSI name";
    symlink = mkBoolOpt false "Create a symlink to the iSCSI binaries";
  };

  config = mkIf cfg.enable {
    boot.kernelModules = [ "iscsi_tcp" "libiscsi" "scsi_transport_iscsi" ];

    services.openiscsi = {
      enable = true;
      name = cfg.name;
    };

    environment.systemPackages = with pkgs; [
      openiscsi
    ];

    # Predominately used for RKE2 & Democratic CSI
    system.activationScripts.iscsi-symlink = mkIf cfg.symlink ''
      mkdir -p /usr/bin
      ln -sf ${pkgs.openiscsi}/bin/iscsiadm /usr/bin/iscsiadm
      ln -sf ${pkgs.openiscsi}/bin/iscsid /usr/bin/iscsid
    '';

    # Cloud Init Compatibility
    environment.etc."iscsi/initiatorname.iscsi".enable = mkIf cloudInitEnabled false;
    systemd.services.iscsi-initiator-setup = mkIf cloudInitEnabled {
      description = "Setup iSCSI Initiator Name";
      requires = [ "cloud-final.service" ];
      before = [ "iscsid.service" ];
      after = [ "cloud-final.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      path = [ pkgs.hostname pkgs.util-linux ];
      script = ''
        mkdir -p /run/iscsi
        echo "InitiatorName=iqn.2025.org.nixos:$(hostname)" > /run/iscsi/initiatorname.iscsi
        mount --bind /run/iscsi/initiatorname.iscsi /etc/iscsi/initiatorname.iscsi
      '';
    };
  };
}
