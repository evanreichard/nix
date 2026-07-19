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
in
{
  options.${namespace}.programs.graphical.wms.hyprland = {
    enable = lib.mkEnableOption "Hyprland";
    mainMod = mkOpt types.str "SUPER" "main modifier key";
    menuMod = mkOpt types.str "SUPER" "menu modifier key (i.e. menuMod + space)";
    monitors = mkOpt (with types; listOf str) [ ", preferred, auto, 1" ] "monitor configuration";
    bluetooth = mkBoolOpt false "Bluetooth tray applet (blueman); requires system services.blueman.enable";
  };

  config = mkIf cfg.enable {
    services.swaync = enabled;

    wayland.windowManager.hyprland = {
      enable = true;
      # Lua Backend - Hyprland 0.55 deprecated hyprlang and home-manager 26.05 defaults configType to "lua".
      configType = "lua";
      extraConfig =
        let
          # Quote unless the value is numeric, so scale can be `2` or `"auto"`.
          luaScalar = v: if builtins.match "[0-9]+(\\.[0-9]+)?" v != null then v else ''"${v}"'';
          mkMonitor =
            s:
            let
              parts = map lib.trim (lib.splitString "," s);
              field = i: if builtins.length parts > i then builtins.elemAt parts i else "";
            in
            ''hl.monitor({ output = "${field 0}", mode = "${field 1}", position = "${field 2}", scale = ${luaScalar (field 3)} })'';
        in
        ''
          local mainMod = "${cfg.mainMod}"
          local menuMod = "${cfg.menuMod}"
          local terminal = ${if terminal == null then "nil" else ''"${terminal}"''}
          local btApplet = ${if cfg.bluetooth then "true" else "false"}

          ${lib.concatMapStringsSep "\n" mkMonitor cfg.monitors}
        ''
        + builtins.readFile ./config/hyprland.lua;
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
          "wlr/workspaces" = {
            on-scroll-up = "hyprctl dispatch workspace e+1";
            on-scroll-down = "hyprctl dispatch workspace e-1";
            all-outputs = true;
            on-click = "activate";
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
            on-click = "pamixer -t";
            on-scroll-up = "pamixer -i 5";
            on-scroll-down = "pamixer -d 5";
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
            on-click = "pamixer --default-source -t";
            on-scroll-up = "pamixer --default-source -i 5";
            on-scroll-down = "pamixer --default-source -d 5";
            scroll-step = 5;
          };
        }
      ];
    };

    home.packages = with pkgs; [
      brightnessctl
      hyprshot
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
