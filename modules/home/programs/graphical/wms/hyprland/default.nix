{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
let
  inherit (lib) types mkIf;
  inherit (lib.${namespace}) mkOpt mkBoolOpt enabled;

  cfg = config.${namespace}.programs.graphical.wms.hyprland;
  graphical = config.${namespace}.programs.graphical;
  terminal =
    if graphical.ghostty.enable then "ghostty"
    else if graphical.kitty.enable then "kitty"
    else null;

  # Quote unless the value is numeric, so scale can be `2` or `"auto"`.
  luaScalar = v: if builtins.match "[0-9]+(\\.[0-9]+)?" v != null then v else ''"${v}"'';
  mkMonitor =
    s:
    let
      parts = map lib.trim (lib.splitString "," s);
      field = i: if builtins.length parts > i then builtins.elemAt parts i else "";
    in
    ''hl.monitor({ output = "${field 0}", mode = "${field 1}", position = "${field 2}", scale = ${luaScalar (field 3)} })'';

  lidSpec = lib.findFirst (s: lib.head (lib.splitString "," s) == cfg.lidInternalOutput) null cfg.monitors;

  lidEnable =
    if lidSpec != null then
      mkMonitor lidSpec
    else
      ''hl.monitor({ output = "${cfg.lidInternalOutput}", mode = "highres", position = "auto", scale = "auto" })'';

  # Hyprland never sees the ACPI lid switch, so this loop is the only thing that can
  # power the internal panel down. External presence is read from sysfs to keep the
  # steady state free of IPC; hyprctl only runs when the on/off state flips.
  lidWatcher = pkgs.writeShellScript "hyprland-lid-output" ''
    set -uo pipefail

    hyprctlBin=${lib.escapeShellArg "${config.wayland.windowManager.hyprland.package}/bin/hyprctl"}
    jqBin=${lib.escapeShellArg "${pkgs.jq}/bin/jq"}
    sleepBin=${lib.escapeShellArg "${pkgs.coreutils}/bin/sleep"}
    internal=${lib.escapeShellArg cfg.lidInternalOutput}

    lidState=$(ls -d /proc/acpi/button/lid/*/state 2>/dev/null | head -1)
    if [ -z "$lidState" ]; then
      echo "no lid switch on this machine" >&2
      exit 0
    fi

    externalConnected() {
      local status name
      for status in /sys/class/drm/card*-*/status; do
        name=$(basename "$(dirname "$status")")
        case "$name" in
          *-eDP-* | *-LVDS-* | *-DSI-*) continue ;;
        esac
        [ "$(cat "$status" 2>/dev/null)" = connected ] && return 0
      done
      return 1
    }

    prev=""
    while :; do
      want=on
      if grep -q closed "$lidState" && externalConnected; then want=off; fi

      if [ "$want" != "$prev" ]; then
        prev=$want
        if [ "$want" = off ]; then
          "$hyprctlBin" eval 'hl.monitor({ output = "'"$internal"'", disabled = true })' >/dev/null 2>&1 || true
        else
          "$hyprctlBin" eval '${lidEnable}' >/dev/null 2>&1 || true
          # Hyprland 0.55 refuses to restore a disabled output on the strength of
          # `disabled = false` alone; only a reload reliably brings the panel back.
          if [ "$("$hyprctlBin" -j monitors 2>/dev/null | "$jqBin" -r --arg n "$internal" '.[] | select(.name == $n) | .disabled')" != "false" ]; then
            "$hyprctlBin" reload >/dev/null 2>&1 || true
          fi
        fi
      fi

      "$sleepBin" 1
    done
  '';
in
{
  options.${namespace}.programs.graphical.wms.hyprland = {
    enable = lib.mkEnableOption "Hyprland";
    mainMod = mkOpt types.str "SUPER" "main modifier key";
    menuMod = mkOpt types.str "SUPER" "menu modifier key (i.e. menuMod + space)";
    monitors = mkOpt (with types; listOf str) [ ", preferred, auto, 1" ] "monitor configuration";
    lidInternalOutput = mkOpt (types.nullOr types.str) null "Internal output to disable while the lid is closed and an external display is connected; must name an entry in `monitors`, whose mode/position/scale are reused when it is re-enabled";
    bluetooth = mkBoolOpt false "Bluetooth tray applet (blueman); requires system services.blueman.enable";
  };

  config = mkIf cfg.enable {
    services.swaync = enabled;
    services.hypridle = {
      enable = true;
      settings.general = {
        lock_cmd = "shan-shui-lock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
        inhibit_sleep = 3;
      };
    };

    wayland.windowManager.hyprland = {
      enable = true;
      # Lua Backend - Hyprland 0.55 deprecated hyprlang and home-manager 26.05 defaults configType to "lua".
      configType = "lua";
      extraConfig =
        ''
          local mainMod = "${cfg.mainMod}"
          local menuMod = "${cfg.menuMod}"
          local terminal = ${if terminal == null then "nil" else ''"${terminal}"''}
          local btApplet = ${if cfg.bluetooth then "true" else "false"}

          ${lib.concatMapStringsSep "\n" mkMonitor cfg.monitors}
        ''
        + builtins.readFile ./config/hyprland.lua;
    };

    systemd.user.services.hyprland-lid-output = mkIf (cfg.lidInternalOutput != null) {
      Unit = {
        Description = "Disable ${cfg.lidInternalOutput} while the lid is closed with an external display attached";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Service = {
        ExecStart = "${lidWatcher}";
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };

    programs.waybar = {
      enable = true;
      style = builtins.readFile ./config/waybar-style.css;
      settings = [
        {
          layer = "top";
          position = "top";
          mode = "dock";
          exclusive = true;
          passthrough = false;
          gtk-layer-shell = true;
          height = 0;
          modules-left = [
            "hyprland/workspaces"
            "hyprland/window"
          ];
          # modules-center = [ "hyprland/window" ];
          modules-right = [
            "tray"
            "cpu"
            "memory"
            "pulseaudio"
            "network"
            "backlight"
            "battery"
            "clock"
          ];
          "hyprland/window" = {
            format = "{}";
          };
          "hyprland/workspaces" = {
            # ponytail: "activate" uses old hyprctl dispatch that breaks with Lua backend (0.55+).
            on-click-use-workspace = "hyprctl dispatch 'hl.dsp.focus({ workspace = {} })'";
            on-scroll-up = "hyprctl dispatch 'hl.dsp.focus({ workspace = \"e+1\" })'";
            on-scroll-down = "hyprctl dispatch 'hl.dsp.focus({ workspace = \"e-1\" })'";
          };
          battery = {
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{icon}";
            format-charging = "󰂄";
            format-plugged = "󰂄";
            format-alt = "{icon}";
            format-icons = [
              "󰂃"
              "󰁺"
              "󰁻"
              "󰁼"
              "󰁽"
              "󰁾"
              "󰁾"
              "󰁿"
              "󰂀"
              "󰂁"
              "󰂂"
              "󰁹"
            ];
          };
          cpu = {
            interval = 10;
            format = "  {}%";
            max-length = 10;
            on-click = "";
          };
          memory = {
            interval = 30;
            format = "  {}%";
            format-alt = "  {used:0.1f}G";
            max-length = 10;
          };

          backlight = {
            format = "{icon}";
            format-icons = [
              "󰋙"
              "󰫃"
              "󰫄"
              "󰫅"
              "󰫆"
              "󰫇"
              "󰫈"
            ];
            on-scroll-up = "brightnessctl s 1%-";
            on-scroll-down = "brightnessctl s +1%";
          };
          tray = {
            icon-size = 13;
            tooltip = false;
            spacing = 10;
          };
          network = {
            interval = 1;
            format-wifi = "󰖩";
            format-ethernet = "󰈀";
            format-linked = "󰈁";
            format-disconnected = "";
            on-click-right = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
            # tooltip-format = ''
            #   <big>Network Details</big>
            #   <tt><small>Interface: {ifname}</small></tt>
            #   <tt><small>IP: {ipaddr}/{cidr}</small></tt>
            #   <tt><small>Gateway: {gwaddr}</small></tt>
            #   <tt><small>󰜷 {bandwidthUpBytes}\n󰜮 {bandwidthDownBytes}</small></tt>'';
            tooltip-format = ''
              <big>Network Details</big>
              <small>
              Interface: {ifname}
              SSID: {essid}
              IP Address: {ipaddr}/{cidr}
              Gateway: {gwaddr}

              󰜷 {bandwidthUpBytes} / 󰜮 {bandwidthDownBytes}
              </small>'';

          };
          clock = {
            format = "   {:%Y-%m-%d %H:%M:%S}";
            interval = 1;
            tooltip-format = ''
              <big>{:%Y %B}</big>
              <tt><small>{calendar}</small></tt>'';
          };
          pulseaudio = {
            format = "{icon}   {volume}%";
            tooltip = false;
            format-muted = "  Muted";
            on-click = "pavucontrol -t 3";
            on-click-right = "pavucontrol -t 4";
            on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
            on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            scroll-step = 5;
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = [
                ""
                ""
                ""
              ];
            };
          };
          "pulseaudio#microphone" = {
            format = "{format_source}";
            tooltip = false;
            format-source = " {volume}%";
            format-source-muted = " Muted";
            on-click = "pavucontrol -t 4";
            on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+";
            on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-";
            scroll-step = 5;
          };
        }
      ];
    };

    home.packages = with pkgs; [
      brightnessctl
      hyprshot
      pavucontrol
      playerctl
      wofi
      wofi-emoji
    ] ++ lib.optional cfg.bluetooth blueman;

    xdg.configFile = {
      "wofi/config".source = ./config/wofi.conf;
      "wofi/style.css".source = ./config/wofi-style.css;
      "uwsp/env".text = ''
        export XCURSOR_SIZE=64
      '';
    };
  };
}
