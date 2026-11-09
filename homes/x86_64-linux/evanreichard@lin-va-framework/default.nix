{ pkgs
, lib
, config
, namespace
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
          monitors = [
            # Order matters: Hyprland's last matching monitor rule wins, so the wildcard
            # sets the fallback and the per-output rules override it. The Dell sits left of
            # the laptop and is vertically centred on it: (1440 - 960) / 2 = 240.
            ", highres, auto, 2"
            "eDP-1, highres, 0x0, 2"
            "desc:Dell Inc. DELL P3425WE, highres, -3440x-240, auto"
          ];
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
        tmux = enabled;
        btop = enabled;
        direnv = enabled;
        conduit = enabled;
        git = enabled;
        k9s = enabled;
        nvim = enabled;
        opencode = enabled;
        pi = enabled;
        omp = enabled;
        herdr = enabled;
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

  sops.secrets = lib.mkIf config.${namespace}.security.sops.enable {
    rke2_kubeconfig = {
      path = "${config.home.homeDirectory}/.kube/lin-va-kube";
    };
  };
}
