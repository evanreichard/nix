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

  reichard = {
    user = {
      enable = true;
      inherit (config.snowfallorg.user) name;
    };

    services = {
      ssh-agent = enabled;
      fusuma = enabled;
      awww = enabled;
      poweralertd = enabled;
    };

    security = {
      sops = enabled;
    };

    programs = {
      graphical = {
        wms.hyprland = {
          enable = true;
          menuMod = "ALT";
        };
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
        pi = enabled;
        scripts.plan-disk-burns = enabled;
      };
    };
  };

  dconf = {
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        cursor-theme = "catppuccin-macchiato-mauve-cursors";
        cursor-size = 24;
      };
    };
  };

  home.packages = with pkgs; [
    orca-slicer
    blender
    freecad
  ];

  home.pointerCursor = {
    gtk.enable = true;
    name = "catppuccin-macchiato-mauve-cursors";
    package = pkgs.catppuccin-cursors.macchiatoMauve;
    size = 24;
  };

  # Kubernetes Secrets
  sops.secrets = lib.mkIf osConfig.${namespace}.security.sops.enable {
    rke2_kubeconfig = {
      path = "${config.home.homeDirectory}/.kube/lin-va-kube";
    };
  };
}
