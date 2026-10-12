{ pkgs
, lib
, config
, namespace
, ...
}:
let
  cfg = config.${namespace}.programs.games.beyondAllReason;
in
{
  options.${namespace}.programs.games.beyondAllReason.enable = lib.mkEnableOption "Beyond All Reason";

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.beyond-all-reason ];
  };
}
