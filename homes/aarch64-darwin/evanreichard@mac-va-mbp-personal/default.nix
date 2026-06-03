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

    programs = {
      graphical = {
        ghostty = enabled;
        ghidra = enabled;
      };

      terminal = {
        btop = enabled;
        direnv = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
        opencode = enabled;
      };
    };

    security = {
      sops = enabled;
    };
  };
}
