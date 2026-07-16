{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.${namespace}.programs.graphical.kitty;
in
{
  options.${namespace}.programs.graphical.kitty = {
    enable = mkEnableOption "Kitty";
  };

  config = mkIf cfg.enable {
    # Enable Bash
    ${namespace}.programs.terminal.bash.enable = true;

    programs.kitty = {
      enable = true;

      font.name = "MesloLGM Nerd Font Mono";

      settings = {
        shell = "${pkgs.bashInteractive}/bin/bash --login";
        confirm_os_window_close = -1;

        # Splits + zoom require the splits/stack layouts.
        enabled_layouts = "splits,stack";

        # Catppuccin Mocha - https://github.com/catppuccin/ghostty/blob/main/themes/catppuccin-mocha.conf
        color0 = "#45475a";
        color1 = "#f38ba8";
        color2 = "#a6e3a1";
        color3 = "#f9e2af";
        color4 = "#89b4fa";
        color5 = "#f5c2e7";
        color6 = "#94e2d5";
        color7 = "#bac2de";
        color8 = "#585b70";
        color9 = "#f38ba8";
        color10 = "#a6e3a1";
        color11 = "#f9e2af";
        color12 = "#89b4fa";
        color13 = "#f5c2e7";
        color14 = "#94e2d5";
        color15 = "#a6adc8";
        background = "#1e1e2e";
        foreground = "#cdd6f4";
        cursor = "#f5e0dc";
        cursor_text_color = "#1e1e2e";
        selection_background = "#353749";
        selection_foreground = "#cdd6f4";
      };

      # Mirrors the Ghostty bindings; cmd -> ctrl+shift on Linux.
      keybindings = {
        # Tabs & Splits
        "ctrl+shift+t" = "new_tab";
        "ctrl+shift+w" = "close_window";
        # super+d mirrors Ghostty's cmd+d; Hyprland does not grab super+d.
        "super+d" = "launch --location=vsplit";
        "super+shift+d" = "launch --location=hsplit";
        "super+shift+enter" = "toggle_layout stack";

        # Navigation - Splits
        "ctrl+shift+left" = "neighboring_window left";
        "ctrl+shift+right" = "neighboring_window right";
        "ctrl+shift+up" = "neighboring_window up";
        "ctrl+shift+down" = "neighboring_window down";
        "ctrl+shift+]" = "next_window";
        "ctrl+shift+[" = "previous_window";

        # Navigation - Tabs
        "ctrl+shift+1" = "goto_tab 1";
        "ctrl+shift+2" = "goto_tab 2";
        "ctrl+shift+3" = "goto_tab 3";
        "ctrl+shift+4" = "goto_tab 4";
        "ctrl+shift+5" = "goto_tab 5";
        "ctrl+shift+6" = "goto_tab 6";
        "ctrl+shift+7" = "goto_tab 7";
        "ctrl+shift+8" = "goto_tab 8";
        "ctrl+shift+9" = "goto_tab 9";

        # Clipboard - copy passes ctrl+c through when there is no selection.
        "ctrl+shift+c" = "copy_or_interrupt";
        "ctrl+shift+v" = "paste_from_clipboard";
      };
    };
  };
}
