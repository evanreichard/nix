{ lib, pkgs, config, namespace, ... }:
let
  inherit (lib) mkIf;
  cfg = config.${namespace}.programs.terminal.k9s;
in
{
  options.${namespace}.programs.terminal.k9s = {
    enable = lib.mkEnableOption "k9s";
  };

  config = mkIf cfg.enable {
    programs.k9s.enable = true;

    home.packages = with pkgs; [
      kubectl
      kubernetes-helm
    ];
  };
}
