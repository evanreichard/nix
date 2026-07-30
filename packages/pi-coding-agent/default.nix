{ lib
, buildNpmPackage
, fetchFromGitHub
, fetchurl
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

let
  version = "0.83.0";
  aiModelData = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
    hash = "sha256-+YPCiiEgkwXtnCdJd+KRMPpNiEjfbN836QlNlcx7xtQ=";
  };
in
buildNpmPackage rec {
  pname = "pi-coding-agent";
  inherit version;

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi-mono";
    rev = "v${version}";
    hash = "sha256-+XRJua2TSXkZMnWtxtLMskSzEHrGEFFyvYcPATi7An4=";
  };

  npmDepsHash = "sha256-AbSfP1Ion8bN309NUBQb1QSn2cIIUjNONmZgls9vnYE=";

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
