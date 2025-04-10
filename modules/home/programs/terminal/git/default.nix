{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.git;
in
{
  options.${namespace}.programs.terminal.git = {
    enable = lib.mkEnableOption "Git";
  };

  config = mkIf cfg.enable {
    programs.git = {
      enable = true;
      userName = "Evan Reichard";
      aliases = {
        lg = "log --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all -n 15";
      };
      includes = [
        {
          path = "~/.config/git/work";
          condition = "gitdir:~/Development/git/work/";
        }
        {
          path = "~/.config/git/personal";
          condition = "gitdir:~/Development/git/personal/";
        }
      ];
      extraConfig = {
        user = {
          email = "evan@reichard.io";
        };
        core = {
          autocrlf = "input";
          safecrlf = "true";
          excludesFile = "~/.config/git/.gitignore";
        };
        column = {
          ui = "auto";
        };
        fetch = {
          prune = true;
          pruneTags = true;
          all = true;
        };
        help = {
          autocorrect = true;
        };
        diff = {
          algorithm = "histogram";
          colorMoved = "plain";
          mnemonicPrefix = true;
          renames = true;
        };
        rebase = {
          autoSquash = true;
          autoStash = true;
          updateRefs = true;
        };
        rerere = {
          enabled = true;
          autoupdate = true;
        };
        commit = {
          verbose = true;
        };
        branch = {
          sort = "-committerdate";
        };
        merge = {
          conflictstyle = "zdiff3";
        };
        push = {
          autoSetupRemote = true;
        };
      };
    };

    programs.gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
      };
    };

    home.packages = with pkgs; [
      gitAndTools.gh
      pre-commit
    ];

    # Copy Configuration
    xdg.configFile = {
      git = {
        source = ./config;
        recursive = true;
      };
    };
  };
}
