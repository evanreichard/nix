{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  pname = "omp";
  version = "18.0.7";

  sources = {
    aarch64-darwin = {
      asset = "omp-darwin-arm64";
      hash = "sha256-dS1GagwiFl+AEPQa6m/X2n6P10TYQfU9Yr+2228hj00=";
    };
    x86_64-darwin = {
      asset = "omp-darwin-x64";
      hash = "sha256-65NRdacNnnBFdTFeXWz1Zqbdy+AtrmePUAHA/ey+M0w=";
    };
    aarch64-linux = {
      asset = "omp-linux-arm64";
      hash = "sha256-a/QSnvC/WVmSiHmyz5769ADslgiVQAXh6+gYPnZJDpA=";
    };
    x86_64-linux = {
      asset = "omp-linux-x64";
      hash = "sha256-TiRorWl05qLt6mIdqCq8qMlexiqDVGMDgcNT3AjHdps=";
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
