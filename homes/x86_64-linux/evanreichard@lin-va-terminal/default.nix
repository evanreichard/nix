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
      ssh-agent = enabled;
      fusuma = enabled;
      swww = enabled;
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
      };
    };
  };


  home.pointerCursor = {
    gtk.enable = true;
    name = "catppuccin-macchiato-mauve-cursors";
    package = pkgs.catppuccin-cursors.macchiatoMauve;
    size = 24;
  };

  # SQLite Configuration
  home.file.".sqliterc".text = ''
    .headers on
    .mode column
  '';
}
