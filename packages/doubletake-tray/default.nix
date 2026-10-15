{ lib
, stdenvNoCC
, python3
, makeWrapper
, wrapGAppsHook3
, gobject-introspection
, gtk3
, libayatana-appindicator
, dbus
, xvfb-run
}:
let
  python = python3.withPackages (packages: [ packages.pygobject3 ]);
in
stdenvNoCC.mkDerivation {
  pname = "doubletake-tray";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [ python makeWrapper wrapGAppsHook3 gobject-introspection ];
  buildInputs = [ gtk3 libayatana-appindicator ];
  nativeCheckInputs = [ dbus xvfb-run ];
  dontWrapGApps = true;
  dontBuild = true;

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export HOME=$(mktemp -d)
    export XDG_RUNTIME_DIR=$(mktemp -d)
    export GDK_BACKEND=x11
    export NO_AT_BRIDGE=1
    export DOUBLETAKE_TRAY_GUI_TESTS=1
    dbus-run-session --config-file=${dbus}/share/dbus-1/session.conf -- xvfb-run -a python3 -m unittest -v
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 tray.py $out/share/doubletake-tray/tray.py
    runHook postInstall
  '';

  preFixup = ''
    makeWrapper ${python}/bin/python3 $out/bin/doubletake-tray \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "$out/share/doubletake-tray/tray.py"
  '';

  meta = {
    description = "Native system tray for the doubletake AirPlay mirroring daemon";
    platforms = lib.platforms.linux;
    mainProgram = "doubletake-tray";
  };
}
