{ lib, config, namespace, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  home.stateVersion = "25.05";

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
        git = enabled;
        k9s = enabled;
        nvim = enabled;
      };
    };
  };

  # SQLite Configuration
  home.file.".sqliterc".text = ''
    .headers on
    .mode column
  '';
}
