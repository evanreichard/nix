{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  pname = "omp";
  version = "17.4.2";

  sources = {
    aarch64-darwin = {
      asset = "omp-darwin-arm64";
      hash = "sha256-NX1eegDsPTUsrF38/roVeB4eLQqQdEeSInF6e13dBAY=";
    };
    x86_64-darwin = {
      asset = "omp-darwin-x64";
      hash = "sha256-OlUgRNxBJr3mHHxHCLkjoILJ42cyzrymABeU0nx+xaE=";
    };
    aarch64-linux = {
      asset = "omp-linux-arm64";
      hash = "sha256-pP3o+CpqIpuBW1KR3BEdtMYFMsst+EhLSsJlQRbL2/w=";
    };
    x86_64-linux = {
      asset = "omp-linux-x64";
      hash = "sha256-IYqGhMKxEla0fii6ExrfsqA+mI7d2FZ72Da3xR3QIAU=";
    };
  };

  inherit (stdenvNoCC.hostPlatform) system;

  source =
    sources.${system}
      or (throw "omp: no prebuilt binary for system '${system}'; supported: ${lib.concatStringsSep ", " (lib.attrNames sources)}");
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  dontUnpack = true;
  dontStrip = true;
  dontPatchELF = true;

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/omp
    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    actual=$($out/bin/omp --version)
    if [ "$actual" != "omp/${version}" ]; then
      echo "version mismatch: expected 'omp/${version}', got '$actual'" >&2
      exit 1
    fi
    $out/bin/omp --smoke-test
    runHook postInstallCheck
  '';

  meta = {
    description = "AI coding agent for the terminal";
    homepage = "https://omp.sh";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "omp";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames sources;
  };
}
