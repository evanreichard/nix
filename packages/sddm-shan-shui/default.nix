{ lib
, callPackage
, fetchgit
, themeConfig ? null
, ...
}:

let
  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/sddm-shan-shui.git";
    rev = "8df65107e4ca81ab1f83113f7d89013a629fed8c";
    hash = "sha256-Nc01PN7yi1AC+EHdWgD7h/L+Hs9xaY7jmLb+ZHxoHX4=";
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
