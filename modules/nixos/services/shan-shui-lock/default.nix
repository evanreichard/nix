{ config, lib, pkgs, namespace, ... }:
let
  cfg = config.${namespace}.services.shan-shui-lock;
  theme = cfg.themePackage;
  launcher = pkgs.writeShellScriptBin "shan-shui-lock" ''
    export QT_QPA_PLATFORM=wayland
    export SHANSHUI_PALETTE=${lib.escapeShellArg cfg.palette}
    export SHANSHUI_LANDSCAPE=file://${theme}/share/sddm/themes/sddm-shan-shui/components/Landscape.qml
    exec ${lib.getExe pkgs.quickshell} -p ${theme}/share/shanshui/locker/shell.qml
  '';
in
{
  options.${namespace}.services.shan-shui-lock = {
    enable = lib.mkEnableOption "Shan Shui Quickshell session locker";
    palette = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-mocha";
      description = "Shared Shan Shui color preset";
    };
    themePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.reichard.sddm-shan-shui;
      description = "Shan Shui package containing the Quickshell locker";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ launcher ];
    security.pam.services = {
      shan-shui-lock-password = {
        useDefaultRules = false;
        rules.auth = lib.mapAttrs (_: rule: builtins.removeAttrs rule [ "name" "settings" ]) (
          lib.filterAttrs (name: _: name != "fprintd") config.security.pam.services.login.rules.auth
        );
      };
      shan-shui-lock-fingerprint = {
        useDefaultRules = false;
        rules.auth.fprintd = {
          order = 1;
          control = "required";
          modulePath = "${config.services.fprintd.package}/lib/security/pam_fprintd.so";
        };
      };
    };
  };
}
