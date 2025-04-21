{ lib, config, namespace, ... }:
let
  inherit (lib.${namespace}) enabled;
in
{
  home.stateVersion = "24.11";

  reichard = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    services = {
      # TODO
      # sops = {
      #   enable = true;
      #   defaultSopsFile = lib.snowfall.fs.get-file "secrets/mac-va-mbp-personal/evanreichard/default.yaml";
      #   sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
      # };
    };

    programs = {
      graphical = {
        ghostty = enabled;
        ghidra = enabled;
      };

      terminal = {
        btop = enabled;
        direnv = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
      };
    };
  };

  # Global Packages
  # programs.jq = enabled;
  # programs.pandoc = enabled;
  # home.packages = with pkgs; [
  #   android-tools
  #   imagemagick
  #   mosh
  #   python311
  #   texliveSmall # Pandoc PDF Dep
  #   google-cloud-sdk
  #   tldr
  # ];

  # SQLite Configuration
  home.file.".sqliterc".text = ''
    .headers on
    .mode column
  '';
}
