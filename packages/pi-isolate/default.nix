{ lib
, stdenvNoCC
, fetchgit
, makeWrapper
, bash
, bubblewrap
, coreutils
, findutils
, gnused
,
}:

stdenvNoCC.mkDerivation {
  pname = "pi-isolate";
  version = "unstable-2026-09-17";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/pi-isolate.git";
    rev = "1220e6b1bd0c2c1521ef761d82c8f8913662b858";
    hash = "sha256-zan8AZ0LALZcYqVZ2hgyKpYTYUOYm9xW9SRcso4yZKk=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # Layout Contract - `bin/pi-isolate` derives the prefix from its own path, and the extension
  # reads `../bin/isolated-bash`, `../bin/isolated-container`, `../flake.lock`, and `../flake.nix`
  # relative to `src/`, so those trees have to stay siblings under one prefix.
  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -r src config prompts "$out/"
    cp flake.lock flake.nix "$out/"
    install -Dm555 bin/isolated-bash "$out/bin/isolated-bash"
    install -Dm555 bin/isolated-container "$out/bin/isolated-container"
    install -Dm555 bin/pi-isolate "$out/bin/pi-isolate"

    # Omp and Nix Stay User-Provided - nix has to be the host installation that owns the store,
    # and omp carries the user's own auth and settings.
    wrapProgram "$out/bin/pi-isolate" \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          bubblewrap
          coreutils
          findutils
          gnused
        ]
      }

    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    test -f "$out/src/index.ts"
    test -f "$out/flake.lock"
    test -x "$out/bin/isolated-bash"
    test -x "$out/bin/isolated-container"
    runHook postInstallCheck
  '';

  meta = {
    description = "Network-isolated bash and brokered Nix package installation for omp";
    homepage = "https://gitea.va.reichard.io/evan/pi-isolate";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "pi-isolate";
    platforms = lib.platforms.linux;
  };
}
