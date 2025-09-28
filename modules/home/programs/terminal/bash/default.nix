{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.bash;
in
{
  options.${namespace}.programs.terminal.bash = {
    enable = lib.mkEnableOption "bash";
  };

  config = mkIf cfg.enable {
    programs.bash = {
      enable = true;
      shellAliases = {
        grep = "grep --color";
        ssh = "TERM=xterm-256color ssh";
      };
      profileExtra = ''
        export COLORTERM=truecolor
        SHELL="$BASH"
        PATH=~/.bin:$PATH
        bind "set show-mode-in-prompt on"

        set -o vi || true
        VISUAL=vim
        EDITOR="$VISUAL"

        fastfetch
        eval "$(thefuck --alias)"
      '';
    };

    programs.powerline-go = {
      enable = true;
      settings = {
        git-mode = "compact";
        theme = "gruvbox";
      };
      modules = [
        "host"
        "cwd"
        "git"
        "docker"
        "venv"
      ];
    };

    programs.readline = {
      enable = true;
      extraConfig = ''
        # Approximate VIM Dracula Colors
        set vi-ins-mode-string \1\e[01;38;5;23;48;5;231m\2 I \1\e[38;5;231;48;5;238m\2\1\e[0m\2
        set vi-cmd-mode-string \1\e[01;38;5;22;48;5;148m\2 C \1\e[38;5;148;48;5;238m\2\1\e[0m\2
      '';
    };

    home.packages = with pkgs; [
      thefuck
      fastfetch
      bashInteractive
      nerd-fonts.meslo-lg
    ];

    home.file.".config/fastfetch/config.jsonc".text = builtins.readFile ./config/fastfetch.jsonc;
  };
}
