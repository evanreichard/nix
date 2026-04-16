{ pkgs
, lib
, config
, namespace
, ...
}:
let
  inherit (lib.${namespace}) enabled;
in
{
  home.stateVersion = "25.11";

  reichard = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    programs = {
      graphical = {
        ghostty = enabled;
      };

      terminal = {
        bash = {
          enable = true;
          customProfile = builtins.readFile ./vm-init.sh;
          customFastFetchLogo = ./prophet.txt;
        };
        aws = enabled;
        btop = enabled;
        claude-code = enabled;
        direnv = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
        opencode = enabled;
        pi = enabled;
        zk = enabled;
      };
    };

    services = {
      # nunc = enabled;
      sketchybar = enabled;
    };

    security = {
      sops = enabled;
    };
  };

  # Global Packages
  programs.jq = enabled;
  programs.pandoc = enabled;
  home.packages = with pkgs; [
    # colima
    docker
    keycastr
    reichard.slack-cli
    _1password-cli
  ];
}
