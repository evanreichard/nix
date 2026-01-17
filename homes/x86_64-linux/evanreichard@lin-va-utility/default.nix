{ pkgs
, lib
, config
, namespace
, osConfig
, ...
}:
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
    };

    security = {
      sops = enabled;
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
}
