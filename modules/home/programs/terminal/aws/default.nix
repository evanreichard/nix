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
      aws-sso-util
      awscli2
      cw
      ssm-session-manager-plugin
    ];
  };
}
