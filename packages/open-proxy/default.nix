{ lib
, buildGoModule
, fetchgit
}:

buildGoModule rec {
  pname = "open-proxy";
  version = "unstable-2026-06-16";

  src = fetchgit {
    url = "https://gitea.va.reichard.io/evan/open-proxy.git";
    rev = "a589341214a1e035b6ce2b2d79870e591a25ccca";
    hash = "sha256-onfvxOl4TdeRrVLD1oJWcnhEDzKFYU/V0qxV1+NpQrg=";
  };

  vendorHash = null;

  meta = {
    description = "Forward `open`/`xdg-open` from a remote VM to the host machine";
    homepage = "https://gitea.va.reichard.io/evan/open-proxy";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ evanreichard ];
    mainProgram = "open-proxy";
  };
}
