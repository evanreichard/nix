{ lib
, buildNpmPackage
, fetchFromGitHub
, fetchurl
, nodejs
, nodejs_22
, firefox
, geckodriver
, alsa-lib
, gtk3
, libX11
, makeWrapper
, pkg-config
, pixman
, cairo
, pango
, libjpeg
, giflib
, librsvg
,
}:

let
  version = "1.4.0";
  aiModelData = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-tA4rqLtvwzKQj4uW6DfcLR/ftF65zTgvWu0RFGKYHjw=";
  };
in
buildNpmPackage rec {
  pname = "pi-coding-agent";
  inherit version;

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi-mono";
    rev = "v${version}";
    hash = "sha256-N9NOpiiZTbOMDMV+CxvJAgtLjJJ1/8NJBGS0cFHkhsc=";
  };

  npmDepsHash = "sha256-aBzVz78IxZQlzPYC72Ufa2YFtkow6nZR24YBYZrv9W0=";

  # UI host API - lets pi-remote run as an extension instead of the launch wrapper.
  # Rebase on every version bump; the tests in the patch are not run by this build.
  patches = [ ./ui-host.patch ];

  nativeBuildInputs = [ pkg-config makeWrapper ];

  buildInputs = [
    pixman
    cairo
    pango
    libjpeg
    giflib
    librsvg
  ];

  # Use the published model data so the build does not need network access.
  preBuild = ''
    mkdir -p packages/ai/src/providers/data
    tar -xzf ${aiModelData} --strip-components=4 \
      -C packages/ai/src/providers/data package/dist/providers/data
    substituteInPlace packages/ai/package.json \
      --replace-fail '"build": "npm run generate-models && npm run build:offline"' \
                     '"build": "npm run build:offline"'
  '';

  passthru = { inherit aiModelData; };

  # Build coding-agent dependencies in topological order.
  buildPhase = ''
    runHook preBuild

    for pkg in telemetry chord tui codemode mcp ai durable env agent coding-agent; do
      (cd packages/$pkg && npm run build)
    done

    runHook postBuild
  '';

  installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/pi-coding-agent $out/bin

      # Copy node_modules and the packages directory
      cp -r node_modules $out/lib/pi-coding-agent/
      cp -r packages $out/lib/pi-coding-agent/

      cat > $out/bin/pi <<EOF
    #!${nodejs}/bin/node
    import('$out/lib/pi-coding-agent/packages/coding-agent/dist/cli.js');
    EOF
      chmod +x $out/bin/pi

      # Camoufox downloads an upstream browser binary that is not Nix-patched.
      wrapProgram $out/bin/pi \
        --prefix PATH : ${lib.makeBinPath [
          nodejs_22
          # evan/pi-web - Browser automation tools are needed for web-fetch support.
          firefox
          geckodriver
        ]} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
          alsa-lib
          gtk3
          libX11
        ]}

      runHook postInstall
  '';

  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://github.com/earendil-works/pi-mono";
    downloadPage = "https://www.npmjs.com/package/@earendil-works/pi-coding-agent";
    changelog = "https://github.com/earendil-works/pi-mono/blob/main/packages/coding-agent/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "pi";
  };
}
