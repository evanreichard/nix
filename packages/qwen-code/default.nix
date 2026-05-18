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
  version = "0.16.0-preview.0";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-UAJNw1RjHRoZqtgIWJ1dOTWnE9LoBpfJCAM0Jay+VPI=";
  };

  npmDepsHash = "sha256-uJtOeNnhbGE7EzTwkNbg2EHLonjHCbdPH5rcV2bgQUw=";
  makeCacheWritable = true;
  npmFlags = [ "--legacy-peer-deps" ];

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

  prePatch = ''
    ${jq}/bin/jq '.dependencies."iconv-lite" = "^0.7.0"' \
      packages/core/package.json > packages/core/package.json.tmp
    mv packages/core/package.json.tmp packages/core/package.json

    ${jq}/bin/jq '
      .packages."packages/core".dependencies."iconv-lite" = "^0.7.0" |
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

  preBuild = ''
    mkdir -p node_modules/@lydell/node-pty
    printf '%s\n' \
      'export interface IPty {' \
      '  pid: number;' \
      '  onData(callback: (data: string) => void): void;' \
      '  onExit(callback: (event: { exitCode: number; signal?: number }) => void): void;' \
      '  kill(signal?: string): void;' \
      '  write(data: string): void;' \
      '  resize(columns: number, rows: number): void;' \
      '  removeListener(event: string, listener: (...args: unknown[]) => void): void;' \
      '  exitCode?: number;' \
      '}' \
      > node_modules/@lydell/node-pty/node-pty.d.ts
  '';

  buildPhase = ''
    runHook preBuild
    npm run generate
    npm run build
    npm run bundle
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/qwen-code
    cp -r dist/* $out/share/qwen-code/
    npm prune --production
    cp -r node_modules $out/share/qwen-code/
    if [ -d $out/share/qwen-code/vendor/ripgrep ]; then
      find $out/share/qwen-code/vendor/ripgrep -type f -name rg -exec sh -c '
        for rg; do
          rm "$rg"
          ln -s ${ripgrep}/bin/rg "$rg"
        done
      ' sh {} +
    fi
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
