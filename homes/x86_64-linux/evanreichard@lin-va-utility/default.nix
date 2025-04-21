{ pkgs, lib, config, namespace, osConfig, ... }:
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
      ssh-agent = enabled;
      fusuma = enabled;
      swww = enabled;
      sops = {
        enable = true;
        defaultSopsFile = lib.snowfall.fs.get-file "secrets/default.yaml";
        sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
      };
    };

    programs = {
      graphical = {
        wms.hyprland = enabled;
        ghostty = enabled;
        ghidra = enabled;
        browsers.firefox = {
          enable = true;
          gpuAcceleration = true;
          hardwareDecoding = true;
        };
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

  # home.packages = with pkgs; [
  #   catppuccin-gtk
  # ];

  dconf = {
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        cursor-theme = "catppuccin-macchiato-mauve-cursors";
        cursor-size = 24;
        # enable-hot-corners = false;
        # font-name = osConfig.${namespace}.system.fonts.default;
        # gtk-theme = cfg.theme.name;
        # icon-theme = cfg.icon.name;
      };
    };
  };


  home.pointerCursor = {
    gtk.enable = true;
    name = "catppuccin-macchiato-mauve-cursors";
    package = pkgs.catppuccin-cursors.macchiatoMauve;
    size = 24;
  };

  # Kubernetes Secrets
  sops.secrets = lib.mkIf osConfig.${namespace}.security.sops.enable {
    rke2_kubeconfig = {
      path = "${config.home.homeDirectory}/.kube/rke2";
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
