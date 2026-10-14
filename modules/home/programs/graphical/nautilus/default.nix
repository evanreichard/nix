{ pkgs, lib, config, namespace, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.${namespace}.programs.graphical.nautilus;
in
{
  options.${namespace}.programs.graphical.nautilus = {
    enable = mkEnableOption "Nautilus file manager with Sushi previews";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      nautilus
      sushi
    ];

    # D-Bus Discovery - The session broker does not discover this service from the Home Manager profile.
    xdg.dataFile."dbus-1/services/org.gnome.NautilusPreviewer.service".source =
      "${pkgs.sushi}/share/dbus-1/services/org.gnome.NautilusPreviewer.service";

    home.file.".local/share/applications/org.gnome.Nautilus.desktop".text = ''
      [Desktop Entry]
      Name=Files
      Comment=Browse files
      Exec=${pkgs.nautilus}/bin/nautilus --new-window %U
      Icon=org.gnome.Nautilus
      Terminal=false
      Type=Application
      Categories=GNOME;GTK;Utility;Core;
      MimeType=inode/directory;
      DBusActivatable=false
    '';
  };
}
