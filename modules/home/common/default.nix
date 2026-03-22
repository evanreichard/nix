{ pkgs, ... }:
{

  home.packages = with pkgs; [
    jnv
    jq
    ncdu
    rg
  ];
}
