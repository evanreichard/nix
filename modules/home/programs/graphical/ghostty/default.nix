{ pkgs, lib, config, namespace, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  inherit (lib) mkIf mkEnableOption optionals;
  cfg = config.${namespace}.programs.graphical.ghostty;
in
{
  options.${namespace}.programs.graphical.ghostty = {
    enable = mkEnableOption "Ghostty";
  };

  config = mkIf cfg.enable {
    programs.bash = {
      enable = true;
      shellAliases = {
        grep = "grep --color";
        ssh = "TERM=xterm-256color ssh";
        flush_dns = "sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder";
        hs = "kubectl exec -n headscale $(kubectl get pod -n headscale -o name) -- headscale";
      };
      profileExtra = ''
        # Source Nix daemon
        # if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        #   . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        # fi

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
    ] ++ optionals isLinux [
      # Pending Darwin @ https://github.com/NixOS/nixpkgs/pull/369788
      ghostty
    ];

    home.file.".config/fastfetch/config.jsonc".text = builtins.readFile ./config/fastfetch.jsonc;
    home.file.".config/ghostty/config".text =
      let
        bashPath = "${pkgs.bashInteractive}/bin/bash";
      in
      builtins.replaceStrings
        [ "@BASH_PATH@" ]
        [ bashPath ]
        (builtins.readFile ./config/ghostty.conf);
  };
}
