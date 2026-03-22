{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
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
  version = "0.61.1";

  src = fetchFromGitHub {
    owner = "badlogic";
    repo = "pi-mono";
    rev = "v${version}";
    hash = "sha256-UvYd1AzwC59t+vR0wvrD4rVAcm1xoJAEWmN25NF7YcY=";
  };

  npmDepsHash = "sha256-nU2A+Q8PzVbjN7H+KAIFVbvETUa9BCO0czl5Yikc7gY=";

  nativeBuildInputs = [ pkg-config ];

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
      --replace-fail '"build": "npm run generate-models && tsgo -p tsconfig.build.json"' \
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

      runHook postInstall
  '';

  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://github.com/badlogic/pi-mono";
    downloadPage = "https://www.npmjs.com/package/@mariozechner/pi-coding-agent";
    changelog = "https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/CHANGELOG.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "pi";
  };
}
