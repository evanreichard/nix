{ pkgs, ... }:
{

  home.packages = with pkgs; [
    jnv
    jq
    mosh
    ncdu
    reichard.codexis
    ripgrep
    sqlite-interactive
    unzip
  ];
}
