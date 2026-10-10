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
    rev = "2dd8cee54873c3f39edb92f54b36183408091df0";
    hash = "sha256-cndZid+RzhhqErK69zsEf+EJRwF/A8Yr1W2+cspmxkA=";
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
