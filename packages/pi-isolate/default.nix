{ lib
, inputs
, pkgs
, fetchgit
, fetchurl
, buildNpmPackage
, makeWrapper
, runCommand
}:

let
  inherit (pkgs.stdenv.hostPlatform) system;

  bunSource =
    {
      x86_64-linux = {
        asset = "bun-linux-x64-baseline.zip";
        hash = "sha256-xngEDxT+BEDrg503y9DOTAUaMtpygGrJfeamqra/co8=";
      };
      aarch64-linux = {
        asset = "bun-linux-aarch64.zip";
        hash = "sha256-VDKLvC2cjgyfiSxUTWbFeoO4QTnjSQnl7oF1jxrI/ac=";
      };
    }
    .${system} or (throw "pi-isolate: unsupported system: ${system}");

  # Bun Pin - The new standalone launcher uses `process.execve`, which is absent from this flake's
  # older unstable Bun. The upstream pi-isolate lock pins nixpkgs-unstable with Bun 1.4.2, so use
  # that same runtime and reference for the worker, launcher, and packaged base profile.
  bun = pkgs.stdenvNoCC.mkDerivation {
    pname = "bun";
    version = "1.4.2";
    src = fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.2/${bunSource.asset}";
      inherit (bunSource) hash;
    };
    nativeBuildInputs = [ pkgs.unzip pkgs.autoPatchelfHook ];
    buildInputs = [ pkgs.openssl ];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      install -Dm755 ./bun "$out/bin/bun"
      ln -s "$out/bin/bun" "$out/bin/bunx"
    '';
  };

  bunReference = "github:NixOS/nixpkgs/e554fab72f81915600f3f449b786fd9af40439a5";

  # Backend Pin - The launcher installs session packages from the Nixpkgs revision recorded in
  # the build manifest, and derives the base-profile key from the same revision/package list. The
  # packaged profile therefore has to be built from that revision/package list. Stable packages
  # come from this flake's nixpkgs; Bun follows the upstream pi-isolate pin above.
  nixpkgsReference = "github:NixOS/nixpkgs/${inputs.nixpkgs.rev}";
  searchChannel = lib.versions.majorMinor inputs.nixpkgs.lib.version;

  target =
    if system == "x86_64-linux" then "linux-x64"
    else if system == "aarch64-linux" then "linux-arm64"
    else throw "pi-isolate: unsupported system: ${system}";

  loaderName =
    if system == "x86_64-linux" then "ld-linux-x86-64.so.2"
    else if system == "aarch64-linux" then "ld-linux-aarch64.so.1"
    else throw "pi-isolate: unsupported loader architecture: ${system}";

  # Transcribed from the upstream `config/base-packages.json`, which `scripts/build-artifacts.ts`
  # reads at build time to embed the per-session installables. The two lists have to match: the
  # install check fails the build if upstream adds or drops a base package.
  basePackages = [
    "bash"
    "bun"
    "nodejs"
    "which"
    "coreutils"
    "findutils"
    "fd"
    "ripgrep"
    "gnugrep"
    "gnused"
    "gawk"
    "diffutils"
    "python3"
    "gdb"
    "file"
    "binutils"
    "strace"
    "patchelf"
    "binwalk"
    "radare2"
    "jq"
    "glibc"
    "nix-ld"
    "bubblewrap"
    "iproute2"
    "util-linux"
    "gzip"
    "xz"
    "unzip"
    "xxd"
  ];

  referenceFor = attribute: if attribute == "bun" then bunReference else nixpkgsReference;

  baseKeyInput = lib.concatStringsSep "\n" (
    builtins.genList
      (index: "${referenceFor (builtins.elemAt basePackages index)}\n${builtins.elemAt basePackages index}")
      (builtins.length basePackages)
  );
  baseKey = builtins.substring 0 24 (builtins.hashString "sha256" baseKeyInput);

  # nix-ld Runtime - The sandbox runs foreign binaries against the base profile's glibc loader,
  # which has to be reachable at the standard interpreter aliases the sandbox exposes.
  compatRuntime = runCommand "pi-isolate-nix-ld-runtime" { } ''
    mkdir -p "$out/bin" "$out/lib" "$out/libexec"
    ln -s ${pkgs.nix-ld}/bin/nix-ld "$out/bin/nix-ld"
    ln -s ${pkgs.nix-ld}/libexec/nix-ld "$out/libexec/nix-ld"
    for library in ${pkgs.glibc}/lib/*; do
      ln -s "$library" "$out/lib/$(basename "$library")"
    done
    test -e "$out/lib/${loaderName}"
  '';

  basePackagePaths = map (attribute: if attribute == "bun" then bun else pkgs.${attribute}) basePackages ++ [ compatRuntime ];

  # Shaped like a real `nix profile` generation so the container backend can adopt the profile
  # instead of rebuilding it, matching the manifest the upstream flake writes.
  baseManifest = pkgs.writeText "pi-isolate-base-manifest.json" (builtins.toJSON {
    version = 3;
    elements = builtins.listToAttrs (
      map
        (attribute: {
          name = attribute;
          value = {
            active = true;
            attrPath = "legacyPackages.${system}.${attribute}";
            storePaths = [ (if attribute == "bun" then bun.outPath else pkgs.${attribute}.outPath) ];
          };
        })
        basePackages
    );
  });

  baseProfile = pkgs.buildEnv {
    name = "pi-isolate-base-profile";
    paths = basePackagePaths;
    postBuild = ''
      install -Dm444 ${baseManifest} "$out/manifest.json"
    '';
  };
in
buildNpmPackage {
  pname = "pi-isolate";
  version = "unstable-2026-09-21";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/pi-isolate.git";
    rev = "657f4618db782710f09a5d121625219b3fd8547e";
    hash = "sha256-tnCdCchEVy0CftA5DHF2ZHO21gE8y22bva+kJt5xf6A=";
  };

  # The Pi package lock omits integrity for these nested registry packages. Fill the published
  # values before fetchNpmDeps parses the lock, and use the duplicate-aware cache fetcher.
  postPatch = ''
    ${pkgs.jq}/bin/jq '
      .packages["node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/chord"].integrity = "sha512-t8QOTf0GTHrsDSfcdtXuA9RCkh6mnR4l25N0SM/sgH7Ih25jH4tGXNbkGs9MWpV5xTu9MRPj4A7Zn1UEwQm9+g=="
      | .packages["node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-agent-core"].integrity = "sha512-c5b2FMdJ7C++HBa6AyBmusdf96gdgRqpF7J+UCq2yVGB28UETJvJ190HkgDWUaLPnOQQPbanjKMAm/TgRmFE2w=="
      | .packages["node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai"].integrity = "sha512-lbRm+EMY6Jx3l+HLpbqbm9Yrhkc5u7EffLk2id+zJQEoBuR5I+tijGiZU8zlnuuCclmQOgH0PVjL9PLbeqJ9MQ=="
      | .packages["node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-telemetry"].integrity = "sha512-IEUMnV6mgHyOMfAxa4CKXoBKKfHM8KxNjbXWM4Bps/iLJcFMf8hQsEZ+95VnVTc7C0cU77Rmdxt773C35jb5AA=="
      | .packages["node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui"].integrity = "sha512-7gTC0XOgQfVWg4yGxwHINBpCnGl9p4KEC7PXIc8gAwc/cyxSW4VuFQrp+r1YD3oM+rBkoepKwAt6w6+VJ7BCaw=="
    ' package-lock.json > package-lock.json.tmp
    mv package-lock.json.tmp package-lock.json
  '';

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-imZ1VH87/NJXzYRRtYsMU1r/DzlOw2LDSGXycxtRuwc=";

  nativeBuildInputs = [ makeWrapper bun pkgs.jq ];

  dontNpmBuild = true;

  # `bun run build` bundles the sandbox tool worker, compiles the standalone launcher, and emits
  # the frozen build manifest. The environment supplies the contract values that the manifest
  # would otherwise recover by parsing the shipped `flake.lock`.
  installPhase = ''
    runHook preInstall

    PI_ISOLATE_BUILD_BASE_KEY=${baseKey} \
    PI_ISOLATE_BUILD_BASE_PROFILE=${baseProfile} \
    PI_ISOLATE_BUILD_NIXPKGS_REFERENCE=${nixpkgsReference} \
    PI_ISOLATE_BUILD_UNSTABLE_REFERENCE=${bunReference} \
    PI_ISOLATE_BUILD_SEARCH_CHANNEL=${searchChannel} \
      bun run build

    mkdir -p "$out/bin"
    cp -r src config prompts worker launcher generated "$out/"
    cp flake.lock flake.nix "$out/"
    for script in isolated-bash isolated-container isolate-launcher pi-isolate omp-isolate; do
      install -Dm555 "bin/$script" "$out/bin/$script"
    done

    # Pi, Omp, nix, docker and podman stay user-provided: the selected host carries its own auth
    # and settings, and the backend has to be the host installation that owns the store.
    for launcher in pi-isolate omp-isolate; do
      wrapProgram "$out/bin/$launcher" \
        --prefix PATH : ${
          lib.makeBinPath [
            pkgs.bash
            pkgs.bubblewrap
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnused
          ]
        }
    done

    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    test -f "$out/src/index.ts"
    test -f "$out/prompts/isolated-system.md"
    test -f "$out/config/gdbinit"
    test -f "$out/flake.lock"
    test -f "$out/generated/build-manifest.json"
    test -f "$out/worker/${target}/worker/tool-worker.js"
    test -x "$out/launcher/${target}/isolate-launcher"
    for binary in isolated-bash isolated-container isolate-launcher pi-isolate omp-isolate; do
      test -x "$out/bin/$binary"
    done

    # Drift Guard - The base-package list is transcribed above, so a mismatch against the
    # manifest the build script produced from the shipped config would silently strand tools.
    test "$(jq -c '.baseProfile.packages' "$out/generated/build-manifest.json")" = '${builtins.toJSON basePackages}'

    runHook postInstallCheck
  '';

  meta = {
    description = "Network-isolated bash and brokered Nix package installation for Pi and OMP";
    homepage = "https://gitea.va.reichard.io/evan/pi-isolate";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "pi-isolate";
    platforms = lib.platforms.linux;
  };
}
