{ lib
, callPackage
, fetchgit
, themeConfig ? null
, ...
}:

let
  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/sddm-shan-shui.git";
    rev = "18d478a6e598106b8d0bcc88e61dabd56c23d02d";
    hash = "sha256-p8iLCip6iPWDxGfzyDpA8foJPEhcLTL+azXzA6KtKEY=";
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
