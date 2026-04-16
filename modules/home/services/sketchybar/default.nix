{ config
, lib
, pkgs
, namespace
, ...
}:
let
  cfg = config.${namespace}.services.sketchybar;

  colors = {
    white = "0xddffffff";
    white_dim = "0x99ffffff";
    bg = "0x1a808080";
    transparent = "0x00000000";
    green = "0xff8ceb34";
    yellow = "0xffe8d44d";
    red = "0xffed4f51";
  };

  sketchybarConfig = ''
    #!/usr/bin/env bash

    COLOR_BG="${colors.bg}"
    COLOR_WHITE="${colors.white}"
    COLOR_WHITE_DIM="${colors.white_dim}"
    COLOR_GREEN="${colors.green}"
    COLOR_YELLOW="${colors.yellow}"
    COLOR_RED="${colors.red}"
    COLOR_TRANSPARENT="${colors.transparent}"

    FONT_FACE="SF Pro"
    NERD_FONT="Symbols Nerd Font Mono:Regular:16.0"
    PADDING=6

    # Bar - transparent, top
    sketchybar --bar \
      height=36 \
      position=top \
      color=$COLOR_TRANSPARENT \
      shadow=off \
      sticky=on \
      topmost=off \
      padding_left=0 \
      padding_right=12 \
      y_offset=3

    # Defaults
    sketchybar --default \
      icon.font="$NERD_FONT" \
      icon.color=$COLOR_WHITE \
      icon.padding_left=$(($PADDING + 2)) \
      icon.padding_right=2 \
      label.font="$FONT_FACE:Medium:13.0" \
      label.color=$COLOR_WHITE \
      label.padding_left=2 \
      label.padding_right=$(($PADDING + 2)) \
      background.color=$COLOR_BG \
      background.corner_radius=6 \
      background.clip=0.5 \
      background.height=32 \
      background.padding_left=4 \
      blur_radius=30 \
      background.padding_right=4

    # Right side items (rightmost → leftmost)

    # Clock
    sketchybar --add item clock right \
      --set clock \
        icon=󰃰 \
        icon.color=$COLOR_WHITE_DIM \
        update_freq=1 \
        script="${pkgs.writeShellScript "sketchybar-clock" ''
          sketchybar --set $NAME label="$(date '+%a %b %-d  %H:%M:%S')"
        ''}"

    # Battery
    sketchybar --add item battery right \
      --set battery \
        update_freq=30 \
        script="${pkgs.writeShellScript "sketchybar-battery" ''
          PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | head -1)"
          CHARGING="$(pmset -g batt | grep -c "AC Power")"
          PCT="''${PERCENTAGE//\%/}"

          if [ "$CHARGING" -gt 0 ]; then
            ICON="󰂄"
            COLOR="${colors.green}"
          elif [ "$PCT" -ge 80 ]; then
            ICON="󰁹"
            COLOR="${colors.green}"
          elif [ "$PCT" -ge 60 ]; then
            ICON="󰂀"
            COLOR="${colors.green}"
          elif [ "$PCT" -ge 40 ]; then
            ICON="󰁾"
            COLOR="${colors.yellow}"
          elif [ "$PCT" -ge 20 ]; then
            ICON="󰁼"
            COLOR="${colors.yellow}"
          else
            ICON="󰁺"
            COLOR="${colors.red}"
          fi

          sketchybar --set $NAME icon="$ICON" icon.color="$COLOR" label="$PERCENTAGE"
        ''}" \
      --subscribe battery power_source_change system_woke

    # Volume
    sketchybar --add item volume right \
      --set volume \
        script="${pkgs.writeShellScript "sketchybar-volume" ''
          VOL="$(osascript -e 'output volume of (get volume settings)')"
          MUTED="$(osascript -e 'output muted of (get volume settings)')"

          if [ "$MUTED" = "true" ]; then
            ICON="󰖁"
          elif [ "$VOL" -ge 60 ]; then
            ICON="󰕾"
          elif [ "$VOL" -ge 30 ]; then
            ICON="󰖀"
          elif [ "$VOL" -gt 0 ]; then
            ICON="󰕿"
          else
            ICON="󰖁"
          fi

          sketchybar --set $NAME icon="$ICON" label="''${VOL}%"
        ''}" \
      --subscribe volume volume_change

    # Wi-Fi
    sketchybar --add item wifi right \
      --set wifi \
        icon=󰖩 \
        icon.color=$COLOR_WHITE_DIM \
        update_freq=10 \
        script="${pkgs.writeShellScript "sketchybar-wifi" ''
          EN="$(networksetup -listallhardwareports | awk '/Wi-Fi|AirPort/{getline; print $NF}')"
          if ipconfig getsummary "$EN" | grep -Fxq "  Active : FALSE"; then
            sketchybar --set $NAME icon=󰖪 label="Off"
          else
            SSID="$(networksetup -listpreferredwirelessnetworks "$EN" | sed -n '2s/^\t//p')"
            if [ -n "$SSID" ]; then
              sketchybar --set $NAME icon=󰖩 label="$SSID"
            else
              sketchybar --set $NAME icon=󰖪 label="Off"
            fi
          fi
        ''}"

    sketchybar --update
  '';
in
{
  options.${namespace}.services.sketchybar = {
    enable = lib.mkEnableOption "sketchybar status bar";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = "reichard.services.sketchybar is only supported on macOS (Darwin).";
      }
    ];

    programs.sketchybar = {
      enable = true;
      extraPackages = [
        pkgs.sketchybar-app-font
      ];
      config = sketchybarConfig;
      service.enable = true;
    };
  };
}
