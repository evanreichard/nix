{ lib
, callPackage
, fetchgit
, themeConfig ? null
, ...
}:

let
  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/sddm-shan-shui.git";
    rev = "7736bc1580d9dc3e8814ccb17d94de5f281fe491";
    hash = "sha256-5TXJIRu8dm1aMRt2klXX/jJDBxD8OECxtgzi0yTj1rs=";
  };
  package = callPackage "${src}/default.nix" (
    lib.optionalAttrs (themeConfig != null) { inherit themeConfig; }
  );
in
package.overrideAttrs (old: {
  meta = old.meta // {
    homepage = "https://gitea.va.reichard.io/evan/sddm-shan-shui";
    maintainers = with lib.maintainers; [ evanreichard ];
  };
})
