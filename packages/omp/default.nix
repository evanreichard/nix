{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  pname = "omp";
  version = "18.0.4";

  sources = {
    aarch64-darwin = {
      asset = "omp-darwin-arm64";
      hash = "sha256-1JMWOIe8+Pd7mZGrchn3dxK1sn3mVk969ygwZKyoSCQ=";
    };
    x86_64-darwin = {
      asset = "omp-darwin-x64";
      hash = "sha256-8hd1L19XnSsiCBhGL8UVrTM+ikEPG7/NYweCW3BSYPU=";
    };
    aarch64-linux = {
      asset = "omp-linux-arm64";
      hash = "sha256-8rfIoBloHt4xSsFlEAwcW1zUkAE5B1lI2oCcAEvsXOc=";
    };
    x86_64-linux = {
      asset = "omp-linux-x64";
      hash = "sha256-lOxC0X1xl1o4HiAzW7PABaf9fuwZsxk1jfbSLyjhazc=";
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
