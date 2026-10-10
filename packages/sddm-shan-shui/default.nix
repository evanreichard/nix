{ lib
, stdenvNoCC
, fetchgit
, nodejs
, ...
}:

stdenvNoCC.mkDerivation {
  pname = "sddm-shan-shui";
  version = "0.1.0";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/sddm-shan-shui.git";
    rev = "d6bae93f887fce08e1d34426461ed94aa0b145e2";
    hash = "sha256-+OeDamtJUZOP00gtoca7M0rYktdJ6KuMAAU/Ar556xA=";
  };

  nativeBuildInputs = [ nodejs ];
  dontBuild = true;
  doCheck = true;

  checkPhase = ''
    runHook preCheck
    bash scripts/test.sh --generator
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    theme=$out/share/sddm/themes/sddm-shan-shui
    mkdir -p "$theme"
    cp Main.qml metadata.desktop theme.conf LICENSE "$theme/"
    cp docs/screenshots/light.png "$theme/preview.png"
    cp -r components vendor assets LICENSES "$theme/"
    runHook postInstall
  '';

  meta = {
    description = "SDDM theme with an infinitely generated Shan Shui landscape";
    homepage = "https://gitea.va.reichard.io/evan/sddm-shan-shui";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    platforms = lib.platforms.linux;
  };
}
