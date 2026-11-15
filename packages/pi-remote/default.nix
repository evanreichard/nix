{ lib
, pkgs
, buildNpmPackage
, fetchgit
, makeWrapper
, nodejs_22
}:

buildNpmPackage rec {
  pname = "pi-remote";
  version = "0.2.0-unstable-2026-11-14";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/pi-remote.git";
    rev = "2ff4198b4bd2b075ae0702db908d0185d6393862";
    hash = "sha256-/V+96KzDkmlTp2WW5DPDFf8M+DcSAJCQnFCRfKfOaj4=";
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-CuBmQMnUSa+OFo9Ql+TvBa0uhfs9mQlOJpkPsleWhtU=";
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
