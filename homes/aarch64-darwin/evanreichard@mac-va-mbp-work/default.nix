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
  home.stateVersion = "26.05";

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
        pi = enabled;
        zk = enabled;
      };
    };

    services = {
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
    keycastr
    reichard.slack-cli
    _1password-cli
  ];
}
