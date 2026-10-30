{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.programs.terminal.herdr;
  toml = pkgs.formats.toml { };
in
{
  options.${namespace}.programs.terminal.herdr = {
    enable = lib.mkEnableOption "herdr";
    settings = lib.mkOption {
      type = toml.type;
      default = { };
      description = "Herdr settings written to config.toml.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.reichard.herdr ];

    ${namespace}.programs.terminal.herdr.settings = {
      onboarding = lib.mkDefault false;
      theme.name = lib.mkDefault "catppuccin";
      terminal.new_cwd = lib.mkDefault "follow";
      keys = {
        prefix = lib.mkDefault "ctrl+b";
        new_tab = lib.mkDefault "prefix+c";
        split_vertical = lib.mkDefault "prefix+%";
        split_horizontal = lib.mkDefault "prefix+\"";
        detach = lib.mkDefault "prefix+d";
      };
      ui = {
        mouse_capture = lib.mkDefault true;
        copy_on_select = lib.mkDefault true;
        tab_bar_position = lib.mkDefault "top";
        tab_bar_right = lib.mkDefault [ { type = "hostname"; } ];
      };
    };

    xdg.configFile."herdr/config.toml".source = toml.generate "herdr-config.toml" cfg.settings;
  };
}
