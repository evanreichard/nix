{ lib
, config
, namespace
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.${namespace}.programs.terminal.zk;
in
{
  options.${namespace}.programs.terminal.zk = {
    enable = lib.mkEnableOption "enable zk";
  };

  config = mkIf cfg.enable {
    programs.zk = {
      enable = true;
    };
    programs.fzf.enable = true;
  };
}
