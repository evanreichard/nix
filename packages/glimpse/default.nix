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
  version = "unstable-2026-05-02";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/glimpse.git";
    rev = "e3d7c28820ed9bd838e96f2419de946685ab8d23";
    hash = "sha256-LtrwD7mkh3wUXr2do3IeKiljHgpxCL8drZrJBI32Bu0=";
  };

  npmDepsHash = "sha256-ycAjPZZqI3ZMIUubJbWy8G6X6LaXDcgdZGswikfkQj8=";

  npmBuildScript = "build";

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
