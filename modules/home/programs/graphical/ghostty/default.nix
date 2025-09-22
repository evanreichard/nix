{ pkgs, lib, config, namespace, ... }:
let
  inherit (pkgs.stdenv) isLinux;
  inherit (lib) mkIf mkEnableOption optionals;
  cfg = config.${namespace}.programs.graphical.ghostty;
in
{
  options.${namespace}.programs.graphical.ghostty = {
    enable = mkEnableOption "Ghostty";
  };

  config = mkIf cfg.enable {
    # Enable Bash
    ${namespace}.programs.terminal.bash.enable = true;

    # Pending Darwin @ https://github.com/NixOS/nixpkgs/pull/369788
    home.packages = with pkgs; optionals isLinux [
      ghostty
    ];

    home.file.".config/ghostty/config".text =
      let
        bashPath = "${pkgs.bashInteractive}/bin/bash";
      in
      builtins.replaceStrings
        [ "@BASH_PATH@" ]
        [ bashPath ]
        (builtins.readFile ./config/ghostty.conf);
  };
}
