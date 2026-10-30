{ lib
, pkgs
, buildNpmPackage
, fetchgit
, makeWrapper
, nodejs_22
}:

buildNpmPackage rec {
  pname = "pi-remote";
  version = "0.2.0-unstable-2026-10-30";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/pi-remote.git";
    rev = "0c18b560f5334663a75c1e73bb8e2a06417ad9aa";
    hash = "sha256-OyY0UQyEut+9sg1pHxPSrM/3HmcxzqTYtHaFt2nk3Mc=";
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-XYgEFmrmJUPNgk1691Q3zEQ64Uo/a3It6rH13dKdQz0=";
  npmFlags = [ "--legacy-peer-deps" ];
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    # Runtime Closure - The browser is already built; retain only the wrapper's production dependency graph.
    npm ci --offline --omit=dev --ignore-scripts --legacy-peer-deps --workspace=@pi-remote/cli

    mkdir -p $out/lib/pi-remote/packages/web $out/bin
    cp package.json $out/lib/pi-remote/
    cp -r extensions node_modules $out/lib/pi-remote/
    for package in cli runtime protocol server; do
      cp -r packages/$package $out/lib/pi-remote/packages/
    done
    cp -r packages/web/dist $out/lib/pi-remote/packages/web/

    makeWrapper ${nodejs_22}/bin/node $out/bin/pi-remote \
      --add-flags "$out/lib/pi-remote/packages/cli/src/cli.ts" \
      --set-default PI_REMOTE_PI_PACKAGE "${pkgs.reichard.pi-coding-agent}/lib/pi-coding-agent/packages/coding-agent"

    runHook postInstall
  '';

  meta = {
    description = "Native browser workspace for Pi, as a wrapper or a patched-Pi extension";
    homepage = "https://gitea.va.reichard.io/evan/pi-remote";
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "pi-remote";
  };
}
