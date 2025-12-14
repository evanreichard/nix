{ lib
, pkgs
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.btop;
in
{
  options.${namespace}.programs.terminal.btop = {
    enable = lib.mkEnableOption "btop";
  };

  config = mkIf cfg.enable {
    programs.btop = {
      enable = true;
      package = pkgs.btop-cuda;
    };

    home.file.".config/btop/btop.conf".text = builtins.readFile ./config/btop.conf;
    home.file.".config/btop/themes/catppuccin_mocha.theme".text =
      builtins.readFile ./config/catppuccin_mocha.theme;
  };
}
