{ pkgs, ... }:
{

  home.packages = with pkgs; [
    jnv
    jq
    mosh
    ncdu
    ripgrep
    sqlite-interactive
    unzip
  ];
}
