{ lib
, buildNpmPackage
, fetchFromGitHub
, jq
, git
, ripgrep
, pkg-config
, glib
, libsecret
, ...
}:
buildNpmPackage (finalAttrs: {
  pname = "qwen-code";
  version = "0.4.0-nightly.20251209.a6a57233";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-s9m1IN6jDDbNPr/vI/UcrauYPiyQTDODarLP3EvnG3Y=";
  };

  npmDepsHash = "sha256-ngAjCCoHLPZ+GgBRmAKbRYaF7l+RK3YGf1kEkwFbyQg=";

  nativeBuildInputs = [
    jq
    pkg-config
    git
  ];

  buildInputs = [
    ripgrep
    glib
    libsecret
  ];

  postPatch = ''
    ${jq}/bin/jq '
      del(.packages."node_modules/node-pty") |
      del(.packages."node_modules/@lydell/node-pty") |
      del(.packages."node_modules/@lydell/node-pty-darwin-arm64") |
      del(.packages."node_modules/@lydell/node-pty-darwin-x64") |
      del(.packages."node_modules/@lydell/node-pty-linux-arm64") |
      del(.packages."node_modules/@lydell/node-pty-linux-x64") |
      del(.packages."node_modules/@lydell/node-pty-win32-arm64") |
      del(.packages."node_modules/@lydell/node-pty-win32-x64") |
      del(.packages."node_modules/keytar") |
      walk(
        if type == "object" and has("dependencies") then
          .dependencies |= with_entries(select(.key | (contains("node-pty") | not) and (contains("keytar") | not)))
        elif type == "object" and has("optionalDependencies") then
          .optionalDependencies |= with_entries(select(.key | (contains("node-pty") | not) and (contains("keytar") | not)))
        else .
        end
      ) |
      walk(
        if type == "object" and has("peerDependencies") then
          .peerDependencies |= with_entries(select(.key | (contains("node-pty") | not) and (contains("keytar") | not)))
        else .
        end
      )
    ' package-lock.json > package-lock.json.tmp && mv package-lock.json.tmp package-lock.json
  '';

  buildPhase = ''
    runHook preBuild
    npm run generate
    npm run bundle
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/qwen-code
    cp -r dist/* $out/share/qwen-code/
    npm prune --production
    cp -r node_modules $out/share/qwen-code/
    find $out/share/qwen-code/node_modules -type l -delete || true
    patchShebangs $out/share/qwen-code
    ln -s $out/share/qwen-code/cli.js $out/bin/qwen
    runHook postInstall
  '';

  meta = {
    description = "Coding agent that lives in digital world";
    homepage = "https://github.com/QwenLM/qwen-code";
    mainProgram = "qwen";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
})
