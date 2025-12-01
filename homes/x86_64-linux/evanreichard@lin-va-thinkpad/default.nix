{ pkgs, lib, config, namespace, osConfig, ... }:
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
      ssh-agent = enabled;
      fusuma = enabled;
      swww = enabled;
      poweralertd = enabled;
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
        strawberry = enabled;
        gimp = enabled;
        wireshark = enabled;
        ghidra = enabled;
        remmina = enabled;
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

  # SQLite Configuration
  home.file.".sqliterc".text = ''
    .headers on
    .mode column
  '';
}
