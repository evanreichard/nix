{ config, lib, pkgs, namespace, ... }:
let
  cfg = config.${namespace}.display-managers.greetd;
  theme = cfg.themePackage;
  passwordPresent = pkgs.writeShellScript "greetd-password-present" ''
    IFS= read -r -d "" password || true
    [[ -n "$password" ]]
  '';
  passwordOnlyRules = lib.mapAttrs (_: rule: builtins.removeAttrs rule [ "name" "settings" ]) (
    lib.filterAttrs (name: _: name != "fprintd") config.security.pam.services.login.rules.auth
  );
  fingerprintProbe = pkgs.writeShellScript "greetd-fingerprint-present" ''
    exec ${pkgs.systemd}/bin/busctl --system --timeout=2s call net.reactivated.Fprint /net/reactivated/Fprint/Manager net.reactivated.Fprint.Manager GetDefaultDevice >/dev/null
  '';
  hyprlandSession = pkgs.writeShellScript "shan-shui-start-hyprland" ''
    # Greeter Handoff - Cage releases tty1 before Hyprland takes over; leave a blank console during that gap.
    if [[ -w /dev/tty1 ]]; then
      printf '\033[2J\033[3J\033[H' > /dev/tty1
    fi
    exec ${lib.getExe pkgs.uwsm} start -e -D Hyprland hyprland.desktop
  '';
  greeter = pkgs.writeShellScriptBin "shan-shui-greeter" ''
    export QT_QPA_PLATFORM=wayland
    export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
    export SHANSHUI_PALETTE=${lib.escapeShellArg cfg.palette}
    export SHANSHUI_DEFAULT_USER=${lib.escapeShellArg cfg.defaultUser}
    export SHANSHUI_FPRINT_PROBE=${if config.services.fprintd.enable then fingerprintProbe else ""}
    export SHANSHUI_UI_SCALE=${builtins.toJSON cfg.uiScale}
    export SHANSHUI_LANDSCAPE=file://${theme}/share/shanshui/landscape/components/Landscape.qml
    export SHANSHUI_SESSIONS=${lib.escapeShellArg (builtins.toJSON cfg.sessions)}
    exec ${lib.getExe pkgs.quickshell} -p ${theme}/share/shanshui/greeter/shell.qml
  '';
in
{
  options.${namespace}.display-managers.greetd = {
    enable = lib.mkEnableOption "greetd with the Shan Shui Quickshell greeter";
    palette = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-mocha";
      description = "Shared Shan Shui color preset";
    };
    defaultUser = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Username prefilled in the greeter; empty leaves the field blank";
    };
    uiScale = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
      description = "Scale the greeter form without scaling the landscape";
    };
    themePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.reichard.shan-shui-greetd;
      description = "Shan Shui package containing the Quickshell greeter";
    };
    sessions = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          command = lib.mkOption { type = lib.types.listOf lib.types.str; };
        };
      });
      default = [{
        name = "Hyprland (UWSM)";
        command = [ "${hyprlandSession}" ];
      }];
      description = "Available Wayland sessions and their launch arguments";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.sessions != [ ];
        message = "reichard.display-managers.greetd.sessions needs at least one session";
      }
      {
        assertion = cfg.uiScale > 0;
        message = "reichard.display-managers.greetd.uiScale must be positive";
      }
    ];
    services.greetd = {
      enable = true;
      settings.default_session.command = "${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe pkgs.cage} -d -s -- ${lib.getExe greeter}";
    };
    security.pam.services = {
      greetd-password = {
        useDefaultRules = false;
        rules.auth = passwordOnlyRules // {
          unix = passwordOnlyRules.unix // {
            args = lib.filter (arg: arg != "nullok") passwordOnlyRules.unix.args;
          };
        };
      };
      greetd.rules.auth = lib.mkForce ({
        password = {
          order = 10300;
          control = "substack";
          modulePath = "greetd-password";
        };
      } // lib.optionalAttrs config.services.fprintd.enable {
        password-present = {
          order = 10100;
          control = "[success=1 default=ignore]";
          modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
          args = [ "expose_authtok" "quiet" "${passwordPresent}" ];
        };
        fprintd = {
          order = 10200;
          control = "sufficient";
          modulePath = "${config.services.fprintd.package}/lib/security/pam_fprintd.so";
        };
      });
    };
  };
}
