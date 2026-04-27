{ lib
, buildNpmPackage
, fetchgit
, firefox
, geckodriver
, makeWrapper
,
}:

buildNpmPackage rec {
  pname = "glimpse";
  version = "unstable-2026-04-26";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/glimpse.git";
    rev = "2f83fa311720a5b68f8a98bbcd2ae9b1563d6a47";
    hash = "sha256-ODbqzBWiN0Z81KDPUbJB1/DPy/iM2rAaUmzqtAgp9QI=";
  };

  npmDepsHash = "sha256-IWzSvrGgkoR6gg7P1m/mwakGOOKmm2OFtBirKgE09Ds=";

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/glimpse \
      --prefix PATH : ${lib.makeBinPath [
        firefox
        geckodriver
      ]}
  '';

  meta = {
    description = "Browser automation CLI for inspecting web pages";
    homepage = "https://gitea.va.reichard.io/evan/glimpse";
    license = lib.licenses.isc;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "glimpse";
  };
}
