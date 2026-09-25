{ pkgs }:
let
  inherit (pkgs) lib;
  inherit (pkgs.kodiPackages) buildKodiAddon kodi-six requests six;
in
buildKodiAddon rec {
  pname = "pm4k";
  version = "1.3.19";
  namespace = "script.plexmod";

  src = pkgs.fetchFromGitHub {
    owner = "pannal";
    repo = "plex-for-kodi";
    rev = version;
    hash = "sha256-AwTdxazfLwsxY8ikpQAu2ao1mkS26VewBOSvYuBZUsc=";
  };
  patches = [ ./stub-end-directory.patch ];

  propagatedBuildInputs = [
    kodi-six
    requests
    six
  ];

  meta = {
    description = "PlexMod for Kodi";
    homepage = "https://github.com/pannal/plex-for-kodi";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.all;
  };
}
