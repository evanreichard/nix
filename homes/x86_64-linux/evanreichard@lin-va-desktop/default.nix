{ lib
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

    services = {
      ssh-agent = enabled;
    };

    programs = {
      terminal = {
        bash = enabled;
        btop = enabled;
        direnv = enabled;
        tmux = enabled;
        git = enabled;
      };
    };
  };
}
