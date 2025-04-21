{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.${namespace}.programs.graphical.ghidra;
in
{
  options.${namespace}.programs.graphical.ghidra = {
    enable = mkEnableOption "Enable Ghidra";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [ ghidra ];
  };
}
