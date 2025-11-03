{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.${namespace}.programs.graphical.strawberry;
in
{
  options.${namespace}.programs.graphical.strawberry = {
    enable = mkEnableOption "Enable Strawberry";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      strawberry
      libgpod
    ];
  };
}
