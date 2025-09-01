{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  home.stateVersion = "25.05";

  reichard = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    services = {
      # TODO
      # sops = {
      #   enable = true;
      #   defaultSopsFile = lib.snowfall.fs.get-file "secrets/mac-va-mbp-work/evanreichard/default.yaml";
      #   sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
      # };
    };

    programs = {
      graphical = {
        ghostty = enabled;
      };

      terminal = {
        btop = enabled;
        direnv = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
        aws = enabled;
      };
    };
  };

  # Global Packages
  programs.jq = enabled;
  programs.pandoc = enabled;
  home.packages = with pkgs; [
    android-tools
    imagemagick
    mosh
    python312
    texliveSmall # Pandoc PDF Dep
    google-cloud-sdk
    tldr
  ];

  # SQLite Configuration
  home.file.".sqliterc".text = ''
    .headers on
    .mode column
  '';
}
