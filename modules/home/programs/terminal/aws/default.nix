{ lib, pkgs, config, namespace, ... }:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.aws;
in
{
  options.${namespace}.programs.terminal.aws = {
    enable = lib.mkEnableOption "AWS";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      cw
      awscli2
      ssm-session-manager-plugin
    ];
  };
}
