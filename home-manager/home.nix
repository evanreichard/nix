{ pkgs, ... }:
let
  inherit (pkgs.lib) optionals;
  inherit (pkgs.stdenv) isLinux isDarwin;
in
{

  imports = [
    ./bash
    ./direnv
    ./ghostty
    ./git
    ./htop
    ./fastfetch
    ./nvim
    ./powerline
    ./readline
  ];

  # Home Manager Config
  home.username = "evanreichard";
  home.homeDirectory = "/Users/evanreichard";
  home.stateVersion = "24.11";
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
    (llama-cpp.overrideAttrs {
      version = "b4539";
      src = pkgs.fetchFromGitHub {
        owner = "ggerganov";
        repo = "llama.cpp";
        tag = "b4539";
        hash = "sha256-zPWx8gdai8OfoBCr2X2oJYg45ipLselYZMrL+MbQ1AY=";
        leaveDotGit = true;
      };
    })
    mosh
    pre-commit
    python311
    ssm-session-manager-plugin
    texliveSmall # Pandoc PDF Dep
    thefuck
    tldr
  ]
  ++ optionals isDarwin [ ]
  ++ optionals isLinux [ ];

  # GitHub CLI
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
    };
  };

  # Misc Programs
  programs.htop.enable = true;
  programs.jq.enable = true;
  programs.k9s.enable = true;
  programs.pandoc.enable = true;

  # Enable Flakes & Commands
  nix = {
    package = pkgs.nix;
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
