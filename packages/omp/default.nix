{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  pname = "omp";
  version = "18.1.17";

  sources = {
    aarch64-darwin = {
      asset = "omp-darwin-arm64";
      hash = "sha256-HDEJdNS+jeTltyhenFJkcyG0EsIZeQ/gJDz4BNXJ1cw=";
    };
    x86_64-darwin = {
      asset = "omp-darwin-x64";
      hash = "sha256-YpnqHJHr6A3ge5goC7Rce433iSog7PT4Gc9mDKfnzuA=";
    };
    aarch64-linux = {
      asset = "omp-linux-arm64";
      hash = "sha256-WKsbj3XSAs83Z+GZAcg00kNYmKGJ1Zk75tXK5nNnFuE=";
    };
    x86_64-linux = {
      asset = "omp-linux-x64";
      hash = "sha256-BAwlTd6zD21ZK+Z9FGncZ/ysFOkz+gTb9pD0KCD/2CA=";
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
    # Smoke test pings a worker that re-executes the whole compiled bundle
    # with a hardcoded 5s pong deadline; under builder load the cold start can
    # exceed it. Retry transient starvation - a broken worker still fails all
    # attempts.
    attempt=1
    maxAttempts=3
    until $out/bin/omp --smoke-test; do
      if [ "$attempt" -ge "$maxAttempts" ]; then
        echo "omp --smoke-test failed after $maxAttempts attempts" >&2
        exit 1
      fi
      attempt=$((attempt + 1))
      echo "omp --smoke-test attempt $attempt/$maxAttempts failed; retrying" >&2
      sleep 2
    done
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
