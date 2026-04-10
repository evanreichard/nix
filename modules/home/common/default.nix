{ pkgs, ... }:
{

  home.packages = with pkgs; [
    sqlite-interactive
    jnv
    jq
    ncdu
    ripgrep
    reichard.codexis
  ];
}
