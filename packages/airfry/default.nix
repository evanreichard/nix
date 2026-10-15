{ lib
, fetchgit
, rustPlatform
, pkg-config
, makeWrapper
, gst_all_1
, gtk4
, libadwaita
, pipewire
, zenity
, libnotify
, dbus
}:
let
  src = fetchgit {
    url = "https://github.com/nored/airfry.git";
    rev = "4b0673041a3093105fc608d325ae508d45c25ef1";
    hash = "sha256-rTRuuIUhv1Hztg5IEYnFGs6C72jfSXIL50Q9ePJRiNA=";
    fetchSubmodules = true;
  };

  gstreamerPlugins = with gst_all_1; [
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
  ];
  runtimeInputs = gstreamerPlugins ++ [ pipewire zenity libnotify ];
in
rustPlatform.buildRustPackage {
  pname = "airfry";
  version = "0.1.0-unstable-2026-06-15";

  inherit src;
  cargoRoot = "rust";
  buildAndTestSubdir = "rust";
  cargoLock.lockFile = "${src}/rust/Cargo.lock";

  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = with gst_all_1; [
    gstreamer
    gst-plugins-base
    gtk4
    libadwaita
    pipewire
    dbus
  ];

  postInstall = ''
    install -Dm644 packaging/airfry.desktop $out/share/applications/airfry.desktop

    for program in $out/bin/airfry $out/bin/airfry-ctl $out/bin/airfry-underscan; do
      wrapProgram "$program" --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" runtimeInputs}" --prefix PATH : "${lib.makeBinPath [ zenity libnotify ]}"
    done
  '';

  meta = {
    description = "Native Linux AirPlay screen-mirroring sender for Apple TV";
    homepage = "https://github.com/nored/airfry";
    license = lib.licenses.mit;
    mainProgram = "airfry";
    platforms = [ "x86_64-linux" ];
  };
}
