{ lib, pkgs, config, namespace, ... }:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.tmux;
in
{
  options.${namespace}.programs.terminal.tmux = {
    enable = lib.mkEnableOption "tmux";
  };

  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      clock24 = true;

      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = catppuccin;
          extraConfig = ''
            set -g @catppuccin_flavor "mocha"
            set -g @catppuccin_status_background "none"

            # Style & Separators
            set -g @catppuccin_window_status_style "basic"
            set -g @catppuccin_status_left_separator "█"
            set -g @catppuccin_status_middle_separator ""
            set -g @catppuccin_status_right_separator "█"

            # Window Titles
            set -g @catppuccin_window_text " #W"
            set -g @catppuccin_window_current_text " #W"
          '';
        }
        cpu
        yank
      ];

      extraConfig = ''
        # Misc Settings
        set -g status-position top
        set -g mouse on
        setw -g mode-keys vi
        set -ag terminal-overrides ",xterm-256color:Tc:Ms=\\E]52;c%p1%.0s;%p2%s\\7"

        # Start Index 1
        set -g base-index 1
        setw -g pane-base-index 1
        set -g renumber-windows on

        # Maintain Directory
        bind '"' split-window -c "#{pane_current_path}"
        bind % split-window -h -c "#{pane_current_path}"
        bind c new-window -c "#{pane_current_path}"

        # Theme
        set -g status-left ""
        set -g status-right ""
        set -ag status-right "#{E:@catppuccin_status_host}"
      '';
    };
  };
}
