{ pkgs, ... }:
let
  inherit (pkgs.lib) optionals mkForce;
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{

  imports = [
    ./bash
    ./btop
    ./direnv
    ./fastfetch
    ./ghostty
    ./git
    ./nvim
    ./powerline
    ./readline
    ./hyprland
    ./waybar
  ];

  # Home Manager Config
  home.stateVersion = "24.11";
  home.username = "evanreichard";
  home.homeDirectory = mkForce (if isLinux then "/home/evanreichard" else "/Users/evanreichard");
  programs.home-manager.enable = true;

  # Global Packages
  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "Meslo" ]; })
    # ghostty - Pending Darwin @ https://github.com/NixOS/nixpkgs/pull/369788
    android-tools
    awscli2
    bashInteractive
    cw
    fastfetch
    gitAndTools.gh
    google-cloud-sdk
    imagemagick
    kubectl
    kubernetes-helm
    mosh
    pre-commit
    python311
    ssm-session-manager-plugin
    texliveSmall # Pandoc PDF Dep
    thefuck
    tldr
  ]
  ++ optionals isLinux [
    ghostty
    hyprpaper
    firefox
  ]
  ++ optionals isDarwin [ ];

  # GitHub CLI
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
  };

  # Misc Programs
  programs.jq.enable = true;
  programs.k9s.enable = true;
  programs.pandoc.enable = true;

  # Enable Flakes & Commands
  nix = {
    package = mkForce pkgs.nix;
    settings = {
      experimental-features = "nix-command flakes";
    };
  };

  # SQLite Configuration
  home.file.".sqliterc".text = ''
    .headers on
    .mode column
  '';

  # Darwin Spotlight Indexing Hack
  disabledModules = [ "targets/darwin/linkapps.nix" ];
}
