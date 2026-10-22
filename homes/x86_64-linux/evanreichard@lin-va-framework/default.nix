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
  home.stateVersion = "26.05";

  services.hyprpolkitagent.enable = true;

  reichard = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    services = {
      ssh-agent = enabled;
      fusuma = enabled;
      awww = enabled;
      darkman.enable = true;
    };

    security.sops = enabled;

    programs = {
      games = {
        beyondAllReason = enabled;
        prismLauncher = enabled;
        steam = enabled;
      };

      graphical = {
        wms.hyprland = {
          enable = true;
          mainMod = "ALT";
          bluetooth = true;
          monitors = [ ",highres,auto,2" ];
        };
        doubletake = {
          enable = true;
          tray = true;
        };
        mpv = enabled;
        ghostty = enabled;
        ghidra = enabled;
        nautilus = enabled;
        gimp = enabled;
        blender = {
          enable = true;
          mcp.enable = true;
        };
        seafile = enabled;
        browsers.firefox = {
          enable = true;
          gpuAcceleration = true;
          hardwareDecoding = true;
        };
      };

      terminal = {
        btop = enabled;
        direnv = enabled;
        conduit = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
        opencode = enabled;
        pi = enabled;
        omp = enabled;
      };
    };
  };

  home.packages = with pkgs; [
    orca-slicer
    solvespace
    vlc
  ];

  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # color-scheme is owned by reichard.services.darkman; managing it here too would
  # be overwritten by the activation hook on every rebuild.
  dconf.settings."org/gnome/desktop/interface" = {
    cursor-theme = "catppuccin-macchiato-mauve-cursors";
    cursor-size = 24;
  };

  home.pointerCursor = {
    gtk.enable = true;
    name = "catppuccin-macchiato-mauve-cursors";
    package = pkgs.catppuccin-cursors.macchiatoMauve;
    size = 24;
  };

  sops.secrets = lib.mkIf osConfig.${namespace}.security.sops.enable {
    rke2_kubeconfig = {
      path = "${config.home.homeDirectory}/.kube/lin-va-kube";
    };
  };
}
