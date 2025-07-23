{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.programs.graphical.wireshark;
in
{
  options.${namespace}.programs.graphical.wireshark = {
    enable = mkEnableOption "Wireshark";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      wireshark
    ];
  };
}
