{ config, lib, pkgs, namespace, ... }:
let
  cfg = config.${namespace}.display-managers.greetd;
  theme = cfg.themePackage;
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
    export SHANSHUI_UI_SCALE=${builtins.toJSON cfg.uiScale}
    export SHANSHUI_LANDSCAPE=file://${theme}/share/sddm/themes/sddm-shan-shui/components/Landscape.qml
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
    uiScale = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
      description = "Scale the greeter form without scaling the landscape";
    };
    themePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.reichard.sddm-shan-shui;
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
    security.pam.services.greetd.fprintAuth = true;
  };
}
