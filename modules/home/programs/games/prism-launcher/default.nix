{ pkgs
, lib
, config
, namespace
, ...
}:
let
  cfg = config.${namespace}.programs.games.prismLauncher;
in
{
  options.${namespace}.programs.games.prismLauncher.enable = lib.mkEnableOption "Prism Launcher";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.prismlauncher ];
  };
}
