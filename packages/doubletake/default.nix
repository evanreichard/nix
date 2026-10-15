{ lib
, buildGoModule
, fetchFromGitHub
, pkg-config
, makeWrapper
, fdk_aac
, gst_all_1
, pipewire
, libpulseaudio
, xrandr
}:
let
  plugins = with gst_all_1; [
    gstreamer.out
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ] ++ [ pipewire ];
  pluginPath = lib.makeSearchPath "lib/gstreamer-1.0" plugins;
in
buildGoModule {
  pname = "doubletake";
  version = "0.5.0-unstable-2026-10-04";

  src = fetchFromGitHub {
    owner = "omarroth";
    repo = "doubletake";
    rev = "5e2f1cbe3e1070bcefec8e549c7baf884727bc00";
    hash = "sha256-ctD5KWrB9O3yA9UrrkQJ10ue2upjDh5gRbl7osAWGPA=";
  };

  vendorHash = "sha256-cgvY9MVGe8I3g3Ni2sGucTY6YCyPJ2YnoxxUaYfl1E4=";

  subPackages = [
    "cmd/doubletake"
    "cmd/doubletake-ctl"
    "cmd/doubletake-test-receiver"
  ];
  tags = [ "fdk_aac" ];
  ldflags = [ "-s" "-w" ];

  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = [ fdk_aac ];

  checkPhase = ''
    runHook preCheck
    go test -tags fdk_aac ./...
    runHook postCheck
  '';

  postInstall = ''
    install -Dm644 man/man1/*.1 -t $out/share/man/man1
    for program in $out/bin/*; do
      wrapProgram "$program" \
        --prefix PATH : "${lib.makeBinPath [ gst_all_1.gstreamer libpulseaudio xrandr ]}" \
        --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${pluginPath}"
    done
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    unset GST_PLUGIN_PATH GST_PLUGIN_PATH_1_0 GST_PLUGIN_SYSTEM_PATH NIX_PROFILES
    export GST_PLUGIN_SYSTEM_PATH_1_0="${pluginPath}"
    export GST_REGISTRY_1_0="$TMPDIR/doubletake-gstreamer-registry.bin"
    export XDG_CACHE_HOME="$TMPDIR"

    for element in queue identity fdsink fakesink pipewiresrc h264parse videoconvert; do
      ${gst_all_1.gstreamer}/bin/gst-inspect-1.0 "$element" > /dev/null
    done
    ${gst_all_1.gstreamer}/bin/gst-launch-1.0 -q \
      videotestsrc num-buffers=3 ! queue ! videoconvert ! x264enc tune=zerolatency ! h264parse ! fdsink fd=1 \
      > "$TMPDIR/doubletake-test.h264"
    test -s "$TMPDIR/doubletake-test.h264"
    runHook postInstallCheck
  '';

  meta = {
    description = "AirPlay screen mirroring sender for Linux";
    homepage = "https://github.com/omarroth/doubletake";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "doubletake";
  };
}
