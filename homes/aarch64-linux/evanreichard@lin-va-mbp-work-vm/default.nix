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
      open-proxy.client = enabled;
    };

    security = {
      pass-keyring = enabled;
      sops = enabled;
    };

    programs = {
      terminal = {
        bash = {
          enable = true;
          customFastFetchLogo = ./prophet.txt;
        };
        conduit = enabled;
        btop = enabled;
        claude-code = enabled;
        direnv = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
        pi = enabled;
        omp = enabled;
        tmux = enabled;
      };
    };
  };
}
