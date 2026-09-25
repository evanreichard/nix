{ pkgs }:
let
  inherit (pkgs) lib;
  kodiPackages = pkgs.kodiPackages;
  python = kodiPackages.kodi.pythonPackages.python.withPackages (p: [ p.pyyaml ]);
in
kodiPackages.buildKodiAddon rec {
  pname = "jellyfin";
  version = "2.2.0";
  namespace = "plugin.video.jellyfin";

  src = pkgs.fetchFromGitHub {
    owner = "jellyfin";
    repo = "jellyfin-kodi";
    rev = "v${version}";
    hash = "sha256-TWDhCOe4EO2HJ/Px+en2++YWniiw4Y+vU3sQtxOvT8U=";
  };

  nativeBuildInputs = [ python ];
  patches = [ "${pkgs.path}/pkgs/applications/video/kodi/addons/jellyfin/no-strict-zip-timestamp.patch" ];

  buildPhase = ''
    ${python}/bin/python3 build.py --version=py3
  '';

  postInstall = ''
    cp addon.xml $out${kodiPackages.addonDir}/${namespace}/
  '';

  propagatedBuildInputs = with kodiPackages; [
    dateutil
    requests
    typing_extensions
    websocket
  ];

  meta = {
    description = "Jellyfin media library integration for Kodi";
    homepage = "https://github.com/jellyfin/jellyfin-kodi";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
}
