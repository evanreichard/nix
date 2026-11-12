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
            # sets the fallback and the per-output rules override it. Both externals are
            # vertically centred on the laptop's 1440x960 logical rect: the 1440-tall Dell
            # gets y = (960 - 1440) / 2 = -240, the 1600-tall LG gets y = (960 - 1600) / 2
            # = -320. Auto scale resolves to ~1.0 on both panels (110-111 ppi).
            ", highres, auto, 2"
            "eDP-1, highres, 0x0, 2"
            "desc:Dell Inc. DELL P3425WE, highres, -3440x-240, auto"
            "desc:LG Electronics LG HDR WQHD, highres, 1440x-320, auto"
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
