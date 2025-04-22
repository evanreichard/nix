{ lib, pkgs, config, namespace, ... }:
let
  inherit (lib) types mkIf;
  inherit (lib.${namespace}) mkOpt enabled;

  cfg = config.${namespace}.programs.graphical.wms.hyprland;
in
{
  options.${namespace}.programs.graphical.wms.hyprland = {
    enable = lib.mkEnableOption "Hyprland";
    mainMod = mkOpt types.str "SUPER" "Hyprland main modifier key";
    monitors = mkOpt (with types; listOf str) [
      ", preferred, auto, 1"
    ] "Hyprland monitor configuration";
  };

  config = mkIf cfg.enable {
    services.swaync = enabled;

    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = builtins.readFile ./config/hyprland.conf;
      settings = {
        "$mainMod" = cfg.mainMod;
        "$terminal" = "ghostty";
        "$menu" = "wofi --show drun";

        monitor = cfg.monitors;

        bind = [
          # Super Bindings (macOS Transition)
          "ALT_SHIFT, 1, exec, hyprshot -m output"
          "ALT_SHIFT, 2, exec, hyprshot -m window"
          "ALT_SHIFT, 3, exec, hyprshot -m region"

          # Primary Bindings
          "$mainMod, SPACE, exec, $menu"
          "$mainMod, RETURN, exec, $terminal"
          "$mainMod, Q, killactive"
          "$mainMod, M, exit"
          "$mainMod, V, togglefloating"
          "$mainMod, P, pin"
          "$mainMod, J, togglesplit"
          "$mainMod, S, togglespecialworkspace, magic"
          "$mainMod SHIFT, S, movetoworkspace, special:magic"

          # Window Focus
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"

          # Workspace Switch
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod, 6, workspace, 6"
          "$mainMod, 7, workspace, 7"
          "$mainMod, 8, workspace, 8"
          "$mainMod, 9, workspace, 9"
          "$mainMod, 0, workspace, 10"

          # Window Workspace Move
          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"
          "$mainMod SHIFT, 6, movetoworkspace, 6"
          "$mainMod SHIFT, 7, movetoworkspace, 7"
          "$mainMod SHIFT, 8, movetoworkspace, 8"
          "$mainMod SHIFT, 9, movetoworkspace, 9"
          "$mainMod SHIFT, 0, movetoworkspace, 10"
          "$mainMod SHIFT, right, workspace, +1"
          "$mainMod SHIFT, left, workspace, -1"
        ];
        bindm = [
          # Window Resizing
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
        bindel = [
          # Multimedia & Brightness Keys
          ",XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ",XF86MonBrightnessUp, exec, brightnessctl s 10%+"
          ",XF86MonBrightnessDown, exec, brightnessctl s 10%-"

          # macOS Keyboard Brightness
          "ALT, XF86MonBrightnessUp, exec, brightnessctl -d kbd_backlight s 10%+"
          "ALT, XF86MonBrightnessDown, exec, brightnessctl -d kbd_backlight s 10%-"
        ];
        bindl = [
          # Player Controls
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPause, exec, playerctl play-pause"
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioPrev, exec, playerctl previous"
        ];
      };
    };

    programs.waybar = {
      enable = true;
      style = builtins.readFile ./config/waybar-style.css;
      settings = [{
        layer = "top";
        position = "top";
        mod = "dock";
        exclusive = true;
        passtrough = false;
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
        "hyprland/window" = { format = "{}"; };
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
            default = [ "" "" "" ];
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
      }];
    };

    home.packages = with pkgs; [
      brightnessctl
      hyprshot
      wofi
      wofi-emoji
    ];

    xdg.configFile = {
      "wofi/config".source = ./config/wofi.conf;
      "wofi/style.css".source = ./config/wofi-style.css;
      "uwsp/env".text = ''
        export XCURSOR_SIZE=64
      '';
    };
  };
}
