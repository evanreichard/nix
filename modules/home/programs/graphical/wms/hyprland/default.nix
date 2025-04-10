{ lib, pkgs, config, namespace, ... }:
let
  inherit (lib) mkIf;
  inherit (lib.${namespace}) enabled;

  cfg = config.${namespace}.programs.graphical.wms.hyprland;
in
{
  options.${namespace}.programs.graphical.wms.hyprland = {
    enable = lib.mkEnableOption "Hyprland";
  };

  config = mkIf cfg.enable {
    services.swaync = enabled;

    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = builtins.readFile ./config/hyprland.conf;
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
