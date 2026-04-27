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
  version = "unstable-2026-04-27";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/glimpse.git";
    rev = "6b3ec32b3ab7a82eb937cc850d217413ec752483";
    hash = "sha256-o4SPiZqsARwDmVpybcYMjyGRdAfDxMTuldWblbMpoCQ=";
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
