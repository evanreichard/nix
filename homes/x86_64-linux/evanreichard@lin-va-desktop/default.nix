{ lib
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

    services = {
      ssh-agent = enabled;
    };

    programs = {
      terminal = {
        bash = enabled;
        btop = enabled;
        tmux = enabled;
      };
    };
  };
}
