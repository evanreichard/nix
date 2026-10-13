{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.${namespace}.services.darkman;
in
{
  options.${namespace}.services.darkman = {
    enable = mkEnableOption "darkman automatic light/dark mode switching";

    latitude = lib.mkOption {
      type = lib.types.float;
      default = 38.9;
      description = "Latitude used to calculate sunrise/sunset";
    };

    longitude = lib.mkOption {
      type = lib.types.float;
      default = -77.0;
      description = "Longitude used to calculate sunrise/sunset";
    };
  };

  config = mkIf cfg.enable {
    services.darkman = {
      enable = true;

      settings = {
        lat = cfg.latitude;
        lng = cfg.longitude;
        usegeoclue = false;
      };

      scripts = {
        # Without this override the Settings portal resolves to xdg-desktop-portal-hyprland,
        # whose .portal file does not advertise org.freedesktop.impl.portal.Settings, so
        # color-scheme never reaches portal clients. A user portals.conf takes full precedence.
        portal-config = ''
          conf="$HOME/.config/xdg-desktop-portal/portals.conf"
          if [ ! -e "$conf" ]; then
            mkdir -p "$(dirname "$conf")"
            printf '[preferred]\norg.freedesktop.impl.portal.Settings=darkman\n' > "$conf"
            systemctl --user restart xdg-desktop-portal.service || true
          fi
        '';

        # darkman seeds scripts with the current mode at startup, so this also
        # maintains the dconf value that nix-dconf-set, Ghostty, and GTK read.
        color-scheme = ''
          dconf write /org/gnome/desktop/interface/color-scheme "'prefer-$1'"
        '';
      };
    };

    # Seeding the value at activation avoids a light-mode flash before darkman starts.
    home.activation.nix-dconf-set = config.lib.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    '';
  };
}
