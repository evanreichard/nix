{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
, nodejs_22
, firefox
, geckodriver
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

buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.77.0";

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi-mono";
    rev = "v${version}";
    hash = "sha256-PJyhLWfqoPjHoYl4pKJVD3uMD5YjQB5YIk5mBZvGi8E=";
  };

  npmDepsHash = "sha256-StMh+5zyJ0nln5rMx5rrGm40A9EcvOIOnGKo/HO4+7g=";

  nativeBuildInputs = [ pkg-config makeWrapper ];

  # Restore NPM Metadata - upstream lockfile omits resolved/integrity entries needed by buildNpmPackage.
  prePatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  buildInputs = [
    pixman
    cairo
    pango
    libjpeg
    giflib
    librsvg
  ];

  # Skip generate-models in ai package (models.generated.ts already in repo)
  preBuild = ''
    substituteInPlace packages/ai/package.json \
      --replace-fail '"build": "npm run generate-models && npm run generate-image-models && tsgo -p tsconfig.build.json"' \
                     '"build": "tsgo -p tsconfig.build.json"'
  '';

  # Build coding-agent dependencies in order
  buildPhase = ''
    runHook preBuild

    cd packages/tui && npm run build && cd ../..
    cd packages/ai && npm run build && cd ../..
    cd packages/agent && npm run build && cd ../..
    cd packages/coding-agent && npm run build && cd ../..

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

      wrapProgram $out/bin/pi \
        --prefix PATH : ${lib.makeBinPath [
          nodejs_22
          # evan/pi-web - Browser automation tools are needed for web-fetch support.
          firefox
          geckodriver
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
