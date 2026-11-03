{ pkgs
, lib
, config
, namespace
, ...
}:
let
  cfg = config.${namespace}.programs.games.steam;
in
{
  options.${namespace}.programs.games.steam.enable = lib.mkEnableOption "Steam";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.steam ];
  };
}
