{ lib
, fetchurl
, libarchive
, stdenvNoCC
,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "omniwm";
  version = "0.6.5";

  src = fetchurl {
    url = "https://github.com/BarutSRB/OmniWM/releases/download/v${finalAttrs.version}/OmniWM-v${finalAttrs.version}.zip";
    hash = "sha256-9eQxUVJ0V1WwutJpprMal9qbv6UqKXBzR9dnPeLpHo0=";
  };

  dontUnpack = true;
  strictDeps = true;

  nativeBuildInputs = [ libarchive ];

  # bsdtar Over unzip - unzip discards the extended attributes holding the Developer ID
  # signature, so the bundle fails Gatekeeper and macOS treats every rebuild as a new,
  # unrecognized binary that must re-request Accessibility permission.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    bsdtar -xf $src -C $out/Applications

    mkdir -p $out/bin
    ln -s $out/Applications/OmniWM.app/Contents/MacOS/OmniWM $out/bin/OmniWM
    ln -s $out/Applications/OmniWM.app/Contents/MacOS/omniwmctl $out/bin/omniwmctl

    runHook postInstall
  '';

  meta = {
    description = "macOS tiling window manager inspired by Niri and Hyprland";
    homepage = "https://github.com/BarutSRB/OmniWM";
    changelog = "https://github.com/BarutSRB/OmniWM/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl2Only;
    mainProgram = "omniwmctl";
    platforms = lib.platforms.darwin;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
