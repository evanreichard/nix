{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "mpv360";
  version = "1.3-unstable-2026-01-30";

  src = fetchFromGitHub {
    owner = "kasper93";
    repo = "mpv360";
    rev = "76f112128d4f372eaee07436ae3a879adafdcc88";
    hash = "sha256-Kb9CfKKIhDkY389a2L5G+lmrKCk8gDlZiO7IL3znL4U=";
  };

  dontBuild = true;

  passthru.scriptName = "mpv360.lua";

  installPhase = ''
    runHook preInstall
    install -Dm644 scripts/mpv360.lua $out/share/mpv/scripts/mpv360.lua
    install -Dm644 shaders/mpv360.glsl $out/share/mpv360/mpv360.glsl
    install -Dm644 script-opts/mpv360.conf $out/share/mpv360/mpv360.conf
    runHook postInstall
  '';

  meta = {
    description = "Interactive 180°/360° video viewer script for mpv";
    homepage = "https://github.com/kasper93/mpv360";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
